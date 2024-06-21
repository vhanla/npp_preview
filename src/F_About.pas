unit F_About;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, NppForms, StdCtrls, ExtCtrls;

type
  TAboutForm = class(TNppForm)
    btnOK: TButton;
    lblBasedOn: TLabel;
    lblTribute, lblTributeContact: TLabel;
    lblPlugin: TLabel;
    lblAuthor, lblAuthorContact: TLabel;
    lblVersion: TLabel;
    lblURL: TLabel;
    lblIEVersion: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure lblLinkClick(Sender: TObject);
  private
    { Private declarations }
    FVersionStr: string;
  public
    { Public declarations }
    procedure ToggleDarkMode; override;
  end;

var
  AboutForm: TAboutForm;

implementation
uses
  ShellAPI, StrUtils,
  IdURI,
  VersionInfo, ModulePath, WebBrowser,
  NppPlugin;

{$R *.dfm}

{ ------------------------------------------------------------------------------------------------ }
procedure TAboutForm.FormCreate(Sender: TObject);
begin
  btnOK.Left := ((Self.Width div 2) - (btnOK.Width div 2) - 12);
  with TFileVersionInfo.Create(TModulePath.DLLFullName) do begin
    FVersionStr := Format('v%d.%d.%d.%d (%d-bit)', [MajorVersion, MinorVersion, Revision, Build, SizeOf(NativeInt)*8]);
    lblVersion.Caption := FVersionStr;
    Free;
  end;

  lblIEVersion.Caption := Format(lblIEVersion.Caption, [GetIEVersion]);
end {TAboutForm.FormCreate};

{ ------------------------------------------------------------------------------------------------ }
procedure TAboutForm.lblLinkClick(Sender: TObject);
var
  URL, Subject: string;
begin
  URL := TLabel(Sender).Hint;
  if StartsText('http', URL) then begin
    with TFileVersionInfo.Create(TModulePath.DLLFullName) do begin
      URL := URL + '?client=' + TIdURI.ParamsEncode(Format('%s/%s', [Internalname, FileVersion])) +
                    '&version=' + TIdURI.ParamsEncode(Format('%d.%d.%d.%d', [MajorVersion, MinorVersion, Revision, Build]));
      Free;
    end;
  end else if StartsText('mailto:', URL) then begin
    with TFileVersionInfo.Create(TModulePath.DLLFullName) do begin
      Subject := Self.Caption + Format(' %s', [FVersionStr]);
      Free;
    end;
    URL := URL + '?subject=' + TIdURI.ParamsEncode(Subject);
  end;
  ShellAPI.ShellExecute(Self.Handle, 'Open', PChar(URL), Nil, Nil, SW_SHOWNORMAL);
  ModalResult := mrCancel;
end {TAboutForm.lblLinkClick};

{ ------------------------------------------------------------------------------------------------ }
procedure TAboutForm.ToggleDarkMode;
begin
end;

end.
