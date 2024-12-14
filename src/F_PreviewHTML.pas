unit F_PreviewHTML;

////////////////////////////////////////////////////////////////////////////////////////////////////
interface

uses
  Windows, Messages, SysUtils, Classes, Variants, Graphics, Controls, Forms, Generics.Collections,
  Dialogs, StdCtrls, SHDocVw, OleCtrls, ComCtrls, ExtCtrls, IniFiles,
  NppPlugin, NppDockingForms,
  WebBrowser,
  U_CustomFilter, uWVBrowserBase, uWVBrowser, uWVWinControl, uWVWindowParent, uWVTypes, uWVConstants,
  uWVTypeLibrary, uWVLibFunctions, uWVLoader, uWVInterfaces, uWVCoreWebView2Args;

type
  TBufferID = NativeInt;

  TfrmHTMLPreview = class(TNppDockingForm)
    pnlButtons: TPanel;
    btnRefresh: TButton;
    btnClose: TButton;
    sbrIE: TStatusBar;
    pnlPreview: TPanel;
    pnlHTML: TPanel;
    btnAbout: TButton;
    tmrAutorefresh: TTimer;
    chkFreeze: TCheckBox;
    WVWindowParent1: TWVWindowParent;
    WVBrowser1: TWVBrowser;
    Timer1: TTimer;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormHide(Sender: TObject);
    procedure FormFloat(Sender: TObject);
    procedure FormDock(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure wbIETitleChange(ASender: TObject; const Text: WideString);
    procedure wbIEBeforeNavigate2(ASender: TObject; const pDisp: IDispatch; const URL, Flags,
      TargetFrameName, PostData, Headers: OleVariant; var Cancel: WordBool);
    procedure wbIENewWindow3(ASender: TObject; var ppDisp: IDispatch; var Cancel: WordBool;
      dwFlags: Cardinal; const bstrUrlContext, bstrUrl: WideString);
    procedure wbIEStatusTextChange(ASender: TObject; const Text: WideString);
    procedure wbIEStatusBar(ASender: TObject; StatusBar: WordBool);
    procedure btnCloseStatusbarClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrAutorefreshTimer(Sender: TObject);
    procedure chkFreezeClick(Sender: TObject);
    procedure wbIEDocumentComplete(ASender: TObject; const pDisp: IDispatch; const URL: OleVariant);
    procedure WVBrowser1AfterCreated(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure WVBrowser1InitializationError(Sender: TObject;
      aErrorCode: HRESULT; const aErrorMessage: wvstring);
    procedure WVBrowser1DocumentTitleChanged(Sender: TObject);
  private
    { Private declarations }
    FBufferID: TBufferID;
    FScrollPositions: TDictionary<TBufferID,TPoint>;
    FFilterThread: TCustomFilterThread;
    FScrollTop: Integer;
    FScrollLeft: Integer;

    procedure SaveScrollPos;
    procedure RestoreScrollPos(const BufferID: TBufferID);

    function  DetermineCustomFilter: string;
    function  ExecuteCustomFilter(const FilterName, HTML: string; const BufferID: TBufferID): Boolean;
    function  TransformXMLToHTML(const XML: WideString): string;

    procedure FilterThreadTerminate(Sender: TObject);
  protected
    procedure WMMove(var aMessage: TWMMove); message WM_MOVE;
    procedure WMMoving(var aMessage: TMessage); message WM_MOVING;
  public
    { Public declarations }
    PrevTimerID: UIntPtr;
    constructor Create(AOwner: TComponent); override;
    procedure ToggleDarkMode; override;
    procedure ResetTimer;
    procedure ForgetBuffer(const BufferID: TBufferID);
    procedure DisplayPreview(HTML: string; const BufferID: TBufferID);
  end;

var
  frmHTMLPreview: TfrmHTMLPreview;

////////////////////////////////////////////////////////////////////////////////////////////////////
implementation
uses
  ShellAPI, ComObj, StrUtils, IOUtils, Masks, MSHTML,
  RegExpr, ModulePath,
  Debug,
  U_Npp_PreviewHTML;

procedure PreviewRefreshTimer(WndHandle: HWND; Msg: UINT; EventID: UINT; TimeMS: UINT); stdcall;
begin
  if Assigned(frmHTMLPreview) then
  begin
    frmHTMLPreview.btnRefresh.Click;
    KillTimer(frmHTMLPreview.Handle, EventID);
  end;
end;

{$R *.dfm}

{ ================================================================================================ }

constructor TfrmHTMLPreview.Create(AOwner: TComponent);
begin
  inherited;
  self.Icon := TIcon.Create;
  self.Icon.Handle := LoadImage(Hinstance, 'TB_PREVIEW_HTML_ICO', IMAGE_ICON, 0, 0, (LR_DEFAULTSIZE or LR_LOADTRANSPARENT));
  self.NppDefaultDockingMask := (DWS_DF_CONT_RIGHT or DWS_USEOWNDARKMODE);
end;

{ ------------------------------------------------------------------------------------------------ }
// Standard components respond poorly to subclassing; see, e.g.,
// https://stackoverflow.com/a/15664777
// https://forum.lazarus.freepascal.org/index.php?topic=22366.0
procedure TfrmHTMLPreview.ToggleDarkMode;
begin
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.FormCreate(Sender: TObject);
begin
  FScrollPositions := TDictionary<TBufferID,TPoint>.Create;
  //self.KeyPreview := true; // special hack for input forms
  self.OnFloat := self.FormFloat;
  self.OnDock := self.FormDock;
  inherited;
  FBufferID := -1;
  with TNppPluginPreviewHTML(Npp).GetSettings() do begin
    tmrAutorefresh.Interval := ReadInteger('Autorefresh', 'Interval', tmrAutorefresh.Interval);
    Free;
  end;
end {TfrmHTMLPreview.FormCreate};
{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FScrollPositions);
  FreeAndNil(FFilterThread);
  FreeAndNil(Icon);
  inherited;
end {TfrmHTMLPreview.FormDestroy};


{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.btnCloseStatusbarClick(Sender: TObject);
begin
  sbrIE.Visible := False;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.tmrAutorefreshTimer(Sender: TObject);
begin
  tmrAutorefresh.Enabled := False;
  btnRefresh.Click;
end {TfrmHTMLPreview.tmrAutorefreshTimer};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.btnRefreshClick(Sender: TObject);
var
  BufferID: TBufferID;
  hScintilla: THandle;
  Lexer: NativeInt;
  IsHTML, IsXML, IsCustom: Boolean;
  Size: WPARAM;
  Content: UTF8String;
  HTML: string;
  FilterName: string;
  CodePage: NativeInt;
begin
  if chkFreeze.Checked then
    Exit;

  try
    tmrAutorefresh.Enabled := False;
ODS('FreeAndNil(FFilterThread);');
    FreeAndNil(FFilterThread);
    SaveScrollPos;

    BufferID := SendMessage(Self.Npp.NppData.NppHandle, NPPM_GETCURRENTBUFFERID, 0, 0);
    hScintilla := Npp.CurrentScintilla;

    Lexer := SendMessage(hScintilla, SCI_GETLEXER, 0, 0);
    IsHTML := (Lexer = SCLEX_HTML);
    IsXML := (Lexer = SCLEX_XML);

    Screen.Cursor := crHourGlass;
    try
      {--- MCO 22-01-2013: determine whether the current document matches a custom filter ---}
      FilterName := DetermineCustomFilter;
      IsCustom := Length(FilterName) > 0;

      {$MESSAGE HINT 'TODO: Find a way to communicate why there is no preview, depending on the situation — MCO 22-01-2013'}

      if IsXML or IsHTML or IsCustom then begin
        CodePage := SendMessage(hScintilla, SCI_GETCODEPAGE, 0, 0);
        Size := SendMessage(hScintilla, SCI_GETTEXT, 0, 0);
        Inc(Size);
        SetLength(Content, Size);
        SendMessage(hScintilla, SCI_GETTEXT, Size, LPARAM(PAnsiChar(Content)));
        if CodePage = CP_ACP then begin
          HTML := string(PAnsiChar(Content));
        end else begin
          SetLength(HTML, Size);
          if Size > 0 then begin
            SetLength(HTML, MultiByteToWideChar(CodePage, 0, PAnsiChar(Content), Size, PWideChar(HTML), Length(HTML)));
            if Length(HTML) = 0 then
              RaiseLastOSError;
          end;
        end;
      end;

      if IsCustom then begin
//MessageBox(Npp.NppData.NppHandle, PChar(Format('FilterName: %s', [FilterName])), 'PreviewHTML', MB_ICONINFORMATION);
        wbIEStatusTextChange(Sender, Format('Running filter %s...', [FilterName]));
        if ExecuteCustomFilter(FilterName, HTML, BufferID) then begin
          Exit;
        end else begin
          wbIEStatusTextChange(Sender, Format('Failed filter %s...', [FilterName]));
          HTML := '<pre style="color: darkred">ExecuteCustomFilter returned False</pre>';
        end;
      end else if IsXML then begin
        HTML := TransformXMLToHTML(HTML);
      end;

      DisplayPreview(HTML, BufferID);
    finally
      Screen.Cursor := crDefault;
    end;
  except
    on E: Exception do begin
ODS('btnRefreshClick ### %s: %s', [E.ClassName, StringReplace(E.Message, sLineBreak, '', [rfReplaceAll])]);
      sbrIE.SimpleText := E.Message;
      sbrIE.Visible := True;
    end;
  end;
end {TfrmHTMLPreview.btnRefreshClick};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.chkFreezeClick(Sender: TObject);
begin
  btnRefresh.Enabled := not chkFreeze.Checked;
  if btnRefresh.Enabled then
    btnRefresh.Click;
end {TfrmHTMLPreview.chkFreezeClick};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.DisplayPreview(HTML: string; const BufferID: TBufferID);
var
  IsHTML: Boolean;
  HeadStart: Integer;
  Size: WPARAM;
  Filename: nppString;
  View: Integer;
  hScintilla: THandle;
begin
ODS('DisplayPreview(HTML: "%s"(%d); BufferID: %x)', [StringReplace(Copy(HTML, 1, 10), #13#10, '', [rfReplaceAll]), Length(HTML), BufferID]);
  try
    IsHTML := Length(HTML) > 0;
    pnlHTML.Visible := IsHTML;
    sbrIE.Visible := IsHTML and (Length(sbrIE.SimpleText) > 0);
    if IsHTML then begin
      Size := SendMessage(Self.Npp.NppData.NppHandle, NPPM_GETFULLPATHFROMBUFFERID, BufferID, LPARAM(nil));
      SetLength(Filename, Size);
      SetLength(Filename, SendMessage(Self.Npp.NppData.NppHandle, NPPM_GETFULLPATHFROMBUFFERID, BufferID, LPARAM(nppPChar(Filename))));
      if (Pos('<base ', HTML) = 0) and FileExists(Filename) then begin
        HeadStart := Pos('<head>', HTML);
        if HeadStart > 0 then
          Inc(HeadStart, 6)
        else
          HeadStart := 1;
        Insert('<base href="' + Filename + '" />', HTML, HeadStart);
      end;

      WVBrowser1.NavigateToString(HTML);

//      if wbIE.GetDocument <> nil then
//        self.UpdateDisplayInfo(wbIE.GetDocument.title)
//      else
        self.UpdateDisplayInfo('');

      {--- 2013-01-26 Martijn: the WebBrowser control has a tendency to steal the focus. We'll let
                                  the editor take it back. ---}
      hScintilla := Npp.CurrentScintilla;
      SendMessage(hScintilla, SCI_GRABFOCUS, 0, 0);
    end else begin
      self.UpdateDisplayInfo('');
    end;

    if pnlHTML.Visible then begin
      Self.AlphaBlend := False;
    end else begin
      Self.AlphaBlend := True;
      Self.AlphaBlendValue := 127;
    end;

    RestoreScrollPos(BufferID);
  except
    on E: Exception do begin
ODS('DisplayPreview ### %s: %s', [E.ClassName, StringReplace(E.Message, sLineBreak, '', [rfReplaceAll])]);
      sbrIE.SimpleText := E.Message;
      sbrIE.Visible := True;
    end;
  end;
end {TfrmHTMLPreview.DisplayPreview};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.SaveScrollPos;
var
  docEl: IHTMLElement2;
  P: TPoint;
begin
  FScrollTop := -1;
  FScrollLeft := -1;
  if FBufferID = -1 then
    Exit;

//  if Assigned(wbIE.Document) and Assigned((wbIE.Document as IHTMLDocument3).documentElement) then begin
//    docEl := (wbIE.Document as IHTMLDocument3).documentElement AS IHTMLElement2;
//    P.Y := docEl.scrollTop;
//    P.X := docEl.scrollLeft;
//    FScrollPositions.AddOrSetValue(FBufferID, P);
//    ODS('SaveScrollPos[%x]: %dx%d', [FBufferID, P.X, P.Y]);
//  end else begin
//    FScrollPositions.Remove(FBufferID);
//    ODS('SaveScrollPos[%x]: --', [FBufferID]);
//  end;
end {TfrmHTMLPreview.SaveScrollPos};

procedure TfrmHTMLPreview.Timer1Timer(Sender: TObject);
begin

  Timer1.Enabled := False;

  if GlobalWebView2Loader.Initialized then
    WVBrowser1.CreateBrowser(WVWindowParent1.Handle)
  else
    Timer1.Enabled := True;
end;

{//************ Explanation ***************
This Delphi code snippet, `TfrmHTMLPreview.SaveScrollPos`, is designed to save the scroll position of an HTML document displayed within a web browser control (`wbIE`). Here's a breakdown of its functionality:

**Purpose:**

The procedure aims to preserve the user's scroll position within a specific HTML document. This is likely part of a larger application that displays multiple HTML documents and needs to remember the user's viewing position in each.

**Code Breakdown:**

1.  **Variable Declarations:**
    *   `docEl: IHTMLElement2;`: Declares a variable `docEl` to hold a reference to an HTML element, specifically the root element of the document. `IHTMLElement2` is an interface that provides access to properties and methods related to HTML elements.
    *   `P: TPoint;`: Declares a `TPoint` variable `P` to store the x and y scroll positions.

2.  **Initialization:**
    *   `FScrollTop := -1;`: Sets a class member variable `FScrollTop` to -1. This variable likely represents the top scroll position. Initializing to -1 suggests it's being reset or invalidated.
    *   `FScrollLeft := -1;`: Similar to `FScrollTop`, sets the class member variable `FScrollLeft` to -1, representing the left scroll position.

3.  **Early Exit Condition:**
    *   `if FBufferID = -1 then Exit;`: Checks the value of `FBufferID`. If it's -1, the procedure exits immediately. This suggests that `FBufferID` acts as an identifier for a specific HTML document (likely within a buffer system). If it's -1, it means there's no valid buffer currently being processed.

4.  **Accessing the HTML Document and its Root Element:**
    *   `if Assigned(wbIE.Document) and Assigned((wbIE.Document as IHTMLDocument3).documentElement) then begin`: This condition checks two crucial things:
        *   `Assigned(wbIE.Document)`: It checks if the web browser control (`wbIE`) has a document loaded. `Assigned` is a Delphi function that checks if a pointer or interface is not `nil`.
        *   `Assigned((wbIE.Document as IHTMLDocument3).documentElement)`: If `wbIE.Document` is valid, it attempts to cast it to the `IHTMLDocument3` interface (which provides more detailed access to the document) and checks if the document has a valid root element (`documentElement`).
    *   If both conditions are true, the following block executes:
        *   `docEl := (wbIE.Document as IHTMLDocument3).documentElement AS IHTMLElement2;`: Retrieves the document's root element (usually the `<html>` tag) and casts it to the `IHTMLElement2` interface.
        *   `P.Y := docEl.scrollTop;`: Reads the vertical scroll position of the root element and stores it in `P.Y`.
        *   `P.X := docEl.scrollLeft;`: Reads the horizontal scroll position of the root element and stores it in `P.X`.
        *   `FScrollPositions.AddOrSetValue(FBufferID, P);`: Saves the scroll position (`P`) associated with the current document identified by `FBufferID`. `FScrollPositions` is likely a data structure (e.g., a dictionary or hashmap) that stores scroll positions for multiple document buffers. The `AddOrSetValue` method either adds a new entry if the `FBufferID` doesn't exist or updates an existing entry.
        *   `ODS('SaveScrollPos[%x]: %dx%d', [FBufferID, P.X, P.Y]);`: Outputs a debug message using `ODS` (Output Debug String) function, displaying the `FBufferID` and the saved horizontal (`P.X`) and vertical (`P.Y`) scroll positions. This helps in tracking the scroll positions during debugging.

5.  **Handling Cases Where the Document or Root Element is Invalid:**
    *   `else begin`: If either `wbIE.Document` or its `documentElement` is not assigned, this `else` block executes.
        *   `FScrollPositions.Remove(FBufferID);`: Removes any existing scroll position entry for the current `FBufferID` from the `FScrollPositions` data structure, since there's no valid document to retrieve the position from.
        *   `ODS('SaveScrollPos[%x]: --', [FBufferID]);`: Outputs a debug message indicating that the scroll position was not saved because the document is invalid.

**In Summary:**

The `SaveScrollPos`
}

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.RestoreScrollPos(const BufferID: TBufferID);
var
  P: TPoint;
  docEl: IHTMLElement2;
begin
  {--- MCO 22-01-2013: Look up this buffer's scroll position; if we know one, wait for the page
                          to finish loading, then restore the scroll position. ---}
  if FScrollPositions.TryGetValue(BufferID, P) then begin
    FScrollTop := P.Y;
    FScrollLeft := P.X;
    ODS('RestoreScrollPos[%x]: %dx%d', [BufferID, P.X, P.Y]);
//    if (FScrollTop <> -1) and Assigned(wbIE.Document) and Assigned((wbIE.Document as IHTMLDocument3).documentElement) then begin
//      docEl := (wbIE.Document as IHTMLDocument3).documentElement as IHTMLElement2;
//      docEl.scrollTop := FScrollTop;
//      docEl.scrollLeft := FScrollLeft;
//      ODS('RestoreScrollPos: done!');
//    end;
  end else begin
    ODS('RestoreScrollPos[%x]: --', [BufferID]);
  end;
  FBufferID := BufferID;
end {TfrmHTMLPreview.RestoreScrollPos};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.ForgetBuffer(const BufferID: TBufferID);
begin
  if FBufferID = BufferID then
    FBufferID := -1;
  if Assigned(FScrollPositions) then begin
    FScrollPositions.Remove(BufferID);
  end;
end {TfrmHTMLPreview.ForgetBuffer};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.ResetTimer;
begin
  tmrAutorefresh.Enabled := False;
  tmrAutorefresh.Enabled := True;
end {TfrmHTMLPreview.ResetTimer};

{ ------------------------------------------------------------------------------------------------ }
function TfrmHTMLPreview.DetermineCustomFilter: string;
var
  DocFileName: nppString;
  Filters: TIniFile;
  Names: TStringList;
  i: Integer;
  Match: Boolean;
  Ext, Language, DocLanguage: string;
  DocLangType, LangType: Integer;
  Extensions: TStringList;
  Filespec: string;
begin
  DocFileName := StringOfChar(#0, MAX_PATH);
  SendMessage(Npp.NppData.NppHandle, NPPM_GETFILENAME, WPARAM(Length(DocFileName)), LPARAM(nppPChar(DocFileName)));
  DocFileName := nppString(nppPChar(DocFileName));

  DocLangType := -1;
  DocLanguage := '';

  ForceDirectories(TNppPluginPreviewHTML(Npp).ConfigDir + '\PreviewHTML');
  Filters := TIniFile.Create(TNppPluginPreviewHTML(Npp).ConfigDir + '\PreviewHTML\Filters.ini');
  Names := TStringList.Create;
  try
    Filters.ReadSections(Names);
    for i := 0 to Names.Count - 1 do begin
      {--- 2013-02-15 Martijn: empty filters should be skipped, and
                      any filter can be disabled by putting a '-' in front of its name. ---}
      if (Length(Names[i]) = 0) or (Names[i][1] = '-') then
        Continue;

      Match := False;

      {--- Martijn 03-03-2013: Test file name ---}
      Filespec := Trim(Filters.ReadString(Names[i], 'Filename', ''));
      if (Filespec <> '') then begin
        // http://docwiki.embarcadero.com/Libraries/XE2/en/System.Masks.MatchesMask#Description
        Match := Match or MatchesMask(ExtractFileName(DocFileName), Filespec);
      end;

      {--- MCO 22-01-2013: Test extension ---}
      Ext := Trim(Filters.ReadString(Names[i], 'Extension', ''));
      if (Ext <> '') then begin
        Extensions := TStringList.Create;
        try
          Extensions.CaseSensitive := False;
          Extensions.Delimiter := ',';
          Extensions.DelimitedText := Ext;
          Match := Match or (Extensions.IndexOf(ExtractFileExt(DocFileName)) > -1);
        finally
          Extensions.Free;
        end;
      end;

      {--- MCO 22-01-2013: Test highlighter language ---}
      Language := Filters.ReadString(Names[i], 'Language', '');
      if Language <> '' then begin
        if DocLangType = -1 then begin
          SendMessage(Npp.NppData.NppHandle, NPPM_GETCURRENTLANGTYPE, WPARAM(0), LPARAM(@DocLangType));
        end;
        if DocLangType > -1 then begin
          if TryStrToInt(Language, LangType) and (LangType = DocLangType) then begin
            Match := True;
          end else begin
            if DocLanguage = '' then begin
              SetLength(DocLanguage, SendMessage(Npp.NppData.NppHandle, NPPM_GETLANGUAGENAME, WPARAM(DocLangType), LPARAM(nil)));
              SetLength(DocLanguage, SendMessage(Npp.NppData.NppHandle, NPPM_GETLANGUAGENAME, WPARAM(DocLangType), LPARAM(PChar(DocLanguage))));
            end;
            if SameText(Language, DocLanguage) then begin
              Match := True;
            end;
          end;
        end;
      end;

      {$MESSAGE HINT 'TODO: Test lexer — MCO 22-01-2013'}

      if Match then
        Exit(Names[i]);
    end;
  finally
    Names.Free;
    Filters.Free;
  end;
end {TfrmHTMLPreview.DetermineCustomFilter};

{ ------------------------------------------------------------------------------------------------ }
function TfrmHTMLPreview.ExecuteCustomFilter(const FilterName, HTML: string; const BufferID: TBufferID): Boolean;
var
  FilterData: TFilterData;
  DocFile: TFileName;
  hScintilla: THandle;
  Filters: TIniFile;
  BufferEncoding: NativeInt;
begin
  FilterData.Name := FilterName;
  FilterData.BufferID := BufferID;

  DocFile := StringOfChar(#0, MAX_PATH);
  SendMessage(Npp.NppData.NppHandle, NPPM_GETFULLCURRENTPATH, WPARAM(Length(DocFile)), LPARAM(PChar(DocFile)));
  DocFile := string(PChar(DocFile));
  FilterData.DocFile := DocFile;
  FilterData.Contents := HTML;

  hScintilla := Npp.CurrentScintilla;
  BufferEncoding := SendMessage(Npp.NppData.NppHandle, NPPM_GETBUFFERENCODING, BufferID, 0);
  case BufferEncoding of
    1, 4: FilterData.Encoding := TEncoding.UTF8;
    2, 6: FilterData.Encoding := TEncoding.BigEndianUnicode;
    3, 7: FilterData.Encoding := TEncoding.Unicode;
    5:    FilterData.Encoding := TEncoding.UTF7;
    else  FilterData.Encoding := TEncoding.ANSI;
  end;
  FilterData.UseBOM := BufferEncoding in [1, 2, 3];
  FilterData.Modified := SendMessage(hScintilla, SCI_GETMODIFY, 0, 0) <> 0;

  Filters := TNppPluginPreviewHTML(Npp).GetSettings('Filters.ini');
  try
    FilterData.FilterInfo := TStringList.Create;
    Filters.ReadSectionValues(FilterName, FilterData.FilterInfo);
  finally
    Filters.Free;
  end;

  FilterData.OnTerminate := FilterThreadTerminate;

  {--- 2013-01-26 Martijn: Create a new TCustomFilterThread ---}
  FFilterThread := TCustomFilterThread.Create(FilterData);
  Result := Assigned(FFilterThread);
end {TfrmHTMLPreview.ExecuteCustomFilter};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.FilterThreadTerminate(Sender: TObject);
begin
ODS('FilterThreadTerminate');
if (Sender as TThread).FatalException is Exception then
begin
  ODS('Fatal %s: "%s"', [((Sender as TThread).FatalException as Exception).ClassName, ((Sender as TThread).FatalException as Exception).Message]);
end else
begin
   PrevTimerID := SetTimer(Handle, 0, tmrAutorefresh.Interval, @PreviewRefreshTimer);
end;
  FFilterThread := nil;
end {TfrmHTMLPreview.FilterThreadTerminate};


{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.btnAboutClick(Sender: TObject);
begin
  (npp as TNppPluginPreviewHTML).CommandShowAbout;
end {TfrmHTMLPreview.btnAboutClick};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.btnCloseClick(Sender: TObject);
begin
  self.Hide;
end {TfrmHTMLPreview.btnCloseClick};

{ ------------------------------------------------------------------------------------------------ }
// special hack for input forms
// This is the best possible hack I could came up for
// memo boxes that don't process enter keys for reasons
// too complicated... Has something to do with Dialog Messages
// I sends a Ctrl+Enter in place of Enter
procedure TfrmHTMLPreview.FormKeyPress(Sender: TObject;
  var Key: Char);
begin
//  if (Key = #13) and (self.Memo1.Focused) then self.Memo1.Perform(WM_CHAR, 10, 0);
end;

{ ------------------------------------------------------------------------------------------------ }
// Docking code calls this when the form is hidden by either "x" or self.Hide
procedure TfrmHTMLPreview.FormHide(Sender: TObject);
begin
  SaveScrollPos;
  SendMessage(self.Npp.NppData.NppHandle, NPPM_SETMENUITEMCHECK, self.CmdID, 0);
  // self.Visible := False;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.FormDock(Sender: TObject);
begin
  ResetTimer;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.FormFloat(Sender: TObject);
begin
  ResetTimer;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.FormShow(Sender: TObject);
begin
  inherited;
  SendMessage(self.Npp.NppData.NppHandle, NPPM_SETMENUITEMCHECK, self.CmdID, 1);
  ResetTimer;

  if GlobalWebView2Loader.InitializationError then
    ShowMessage(GlobalWebView2Loader.ErrorMessage)
  else
    if GlobalWebView2Loader.Initialized then
      WVBrowser1.CreateBrowser(WVWindowParent1.Handle)
    else
      Timer1.Enabled := True;
end;

{ ------------------------------------------------------------------------------------------------ }
function TfrmHTMLPreview.TransformXMLToHTML(const XML: WideString): string;
  { - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
  function CreateDOMDocument: OleVariant;
  var
    nVersion: Integer;
  begin
    VarClear(Result);
    for nVersion := 7 downto 4 do begin
      try
        Result := CreateOleObject(Format('MSXML2.DOMDocument.%d.0', [nVersion]));
        if not VarIsClear(Result) then begin
          if nVersion >= 4 then begin
            Result.setProperty('NewParser', True);
          end;
          if nVersion >= 6 then begin
            Result.setProperty('AllowDocumentFunction', True);
            Result.setProperty('AllowXsltScript', True);
            Result.setProperty('ResolveExternals', True);
            Result.setProperty('UseInlineSchema', True);
            Result.setProperty('ValidateOnParse', False);
          end;
          Break;
        end;
      except
        VarClear(Result);
      end;
    end{for};
  end {CreateDOMDocument};
  { - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
var
  bMethodHTML: Boolean;
  xDoc, xPI, xStylesheet, xOutput: OleVariant;
  rexHref: TRegExpr;
begin
  Result := '';
  try
    try
      {--- MCO 30-05-2012: Check to see if there's an xml-stylesheet to convert the XML to HTML. ---}
      xDoc := CreateDOMDocument;
      if VarIsClear(xDoc) then Exit;
      if not xDoc.LoadXML(XML) then Exit;

      xPI := xDoc.selectSingleNode('//processing-instruction("xml-stylesheet")');
      if VarIsClear(xPI) then Exit;

      rexHref := TRegExpr.Create;
      try
        rexHref.ModifierI := False;
        rexHref.Expression := '(^|\s+)href=["'']([^"'']*?)["'']';
        if not rexHref.Exec(xPI.nodeValue) then Exit;

        xStylesheet := CreateDOMDocument;
        if not xStylesheet.Load(rexHref.Match[2]) then Exit;
      finally
        rexHref.Free;
      end;

      bMethodHTML := SameText(xDoc.documentElement.nodeName, 'html');
      if not bMethodHTML then begin
        xStylesheet.setProperty('SelectionNamespaces', 'xmlns:xsl="http://www.w3.org/1999/XSL/Transform"');
        xOutput := xStylesheet.selectSingleNode('/*/xsl:output');
        if VarIsClear(xOutput) then
          Exit;

        bMethodHTML := SameStr(VarToStrDef(xOutput.getAttribute('method'), 'xml'), 'html');
      end;
      if not bMethodHTML then Exit;

      Result := xDoc.transformNode(xStylesheet.documentElement);
    except
      on E: Exception do begin
        {--- MCO 30-05-2012: Ignore any errors; we weren't able to perform the transformation ---}
        Result := '<html><title>Error transforming XML to HTML</title><body><pre style="color: red">' + StringReplace(E.Message, '<', '&lt;', [rfReplaceAll]) + '</pre></body></html>';
      end;
    end;
  finally
    VarClear(xOutput);
    VarClear(xStylesheet);
    VarClear(xPI);
    VarClear(xDoc);
  end;
end {TfrmHTMLPreview.TransformXMLToHTML};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.wbIEBeforeNavigate2(ASender: TObject; const pDisp: IDispatch; const URL,
  Flags, TargetFrameName, PostData, Headers: OleVariant; var Cancel: WordBool);
var
  Handle: HWND;
begin
  if not SameText(URL, 'about:blank') and not StartsText('javascript:', URL) then begin
    if Assigned(Npp) then
      Handle := Npp.NppData.NppHandle
    else
      Handle := 0;
    ShellExecute(Handle, nil, PChar(VarToStr(URL)), nil, nil, SW_SHOWDEFAULT);
    Cancel := True;
  end;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.wbIEDocumentComplete(ASender: TObject; const pDisp: IDispatch;
  const URL: OleVariant);
var
  docEl: IHTMLElement2;
begin
//  if (FScrollTop <> -1) and Assigned(wbIE.Document) and Assigned((wbIE.Document as IHTMLDocument3).documentElement) then begin
//    docEl := (wbIE.Document as IHTMLDocument3).documentElement as IHTMLElement2;
//    docEl.scrollTop := FScrollTop;
//    docEl.scrollLeft := FScrollLeft;
//    FScrollTop := -1;
//    FScrollLeft := -1;
//  end;
end {TfrmHTMLPreview.wbIEDocumentComplete};

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.wbIENewWindow3(ASender: TObject; var ppDisp: IDispatch;
  var Cancel: WordBool; dwFlags: Cardinal; const bstrUrlContext, bstrUrl: WideString);
var
  Handle: HWND;
begin
  if not SameText(bstrUrl, 'about:blank') and not StartsText('javascript:', bstrURL) then begin
    if Assigned(Npp)  then
      Handle := Npp.NppData.NppHandle
    else
      Handle := 0;
    ShellExecute(Handle, nil, PChar(bstrUrl), nil, nil, SW_SHOWDEFAULT);
  end;
  Cancel := True;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.wbIEStatusBar(ASender: TObject; StatusBar: WordBool);
begin
  sbrIE.Visible := StatusBar;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.wbIEStatusTextChange(ASender: TObject; const Text: WideString);
begin
  sbrIE.SimpleText := Text;
  sbrIE.Visible := Length(Text) > 0;
  if sbrIE.Visible then
  sbrIE.Invalidate;
end;

{ ------------------------------------------------------------------------------------------------ }
procedure TfrmHTMLPreview.wbIETitleChange(ASender: TObject; const Text: WideString);
begin
  inherited;
  self.UpdateDisplayInfo(StringReplace(Text, 'about:blank', '', [rfReplaceAll]));
end;

procedure TfrmHTMLPreview.WMMove(var aMessage: TWMMove);
begin
  inherited;

  if (WVBrowser1 <> nil) then
    WVBrowser1.NotifyParentWindowPositionChanged;

end;

procedure TfrmHTMLPreview.WMMoving(var aMessage: TMessage);
begin
  inherited;

  if (WVBrowser1 <> nil) then
    WVBrowser1.NotifyParentWindowPositionChanged;
end;

procedure TfrmHTMLPreview.WVBrowser1AfterCreated(Sender: TObject);
begin
//  inherited;
  WVWindowParent1.UpdateSize;
  WVWindowParent1.SetFocus;
end;

procedure TfrmHTMLPreview.WVBrowser1DocumentTitleChanged(Sender: TObject);
begin
  inherited;
  self.UpdateDisplayInfo(StringReplace(Text, 'about:blank', '', [rfReplaceAll]));
end;

procedure TfrmHTMLPreview.WVBrowser1InitializationError(Sender: TObject;
  aErrorCode: HRESULT; const aErrorMessage: wvstring);
begin
  ShowMessage(aErrorMessage);
end;

////////////////////////////////////////////////////////////////////////////////////////////////////
initialization
  GlobalWebView2Loader                := TWVLoader.Create(nil);
  GlobalWebView2Loader.UserDataFolder := 'C:\NPPPreview\Cache';
  GlobalWebView2Loader.StartWebView2;

finalization
  if Assigned(frmHTMLPreview) then
    KillTimer(frmHTMLPreview.Handle, frmHTMLPreview.PrevTimerID);

end.
