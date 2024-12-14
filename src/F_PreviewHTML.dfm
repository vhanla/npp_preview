object frmHTMLPreview: TfrmHTMLPreview
  Left = 0
  Top = 0
  BorderStyle = bsSizeToolWin
  Caption = 'HTML preview'
  ClientHeight = 420
  ClientWidth = 504
  Color = clBtnFace
  ParentFont = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnKeyPress = FormKeyPress
  OnShow = FormShow
  TextHeight = 15
  object pnlButtons: TPanel
    Left = 0
    Top = 364
    Width = 504
    Height = 56
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      504
      56)
    object btnRefresh: TButton
      Left = 8
      Top = 6
      Width = 75
      Height = 25
      Caption = '&Refresh'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object btnClose: TButton
      Left = 410
      Top = 6
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'Close'
      TabOrder = 4
      OnClick = btnCloseClick
    end
    object sbrIE: TStatusBar
      AlignWithMargins = True
      Left = 3
      Top = 34
      Width = 498
      Height = 19
      Panels = <>
      SimplePanel = True
    end
    object btnAbout: TButton
      Left = 372
      Top = 6
      Width = 25
      Height = 25
      Hint = 'About|About this plugin'
      Anchors = [akTop, akRight]
      Caption = '?'
      TabOrder = 2
      OnClick = btnAboutClick
    end
    object chkFreeze: TCheckBox
      Left = 89
      Top = 10
      Width = 50
      Height = 17
      Caption = '&Freeze'
      TabOrder = 1
      OnClick = chkFreezeClick
    end
  end
  object pnlPreview: TPanel
    Left = 0
    Top = 0
    Width = 504
    Height = 364
    Align = alClient
    BevelOuter = bvNone
    Caption = '(no preview available)'
    TabOrder = 1
    object pnlHTML: TPanel
      Left = 0
      Top = 0
      Width = 504
      Height = 364
      Align = alClient
      BevelOuter = bvNone
      Caption = 'pnlHTML'
      TabOrder = 0
      object WVWindowParent1: TWVWindowParent
        Left = 0
        Top = 0
        Width = 504
        Height = 364
        Align = alClient
        TabOrder = 0
        Browser = WVBrowser1
        ExplicitLeft = 128
        ExplicitTop = 128
        ExplicitWidth = 100
        ExplicitHeight = 41
      end
    end
  end
  object tmrAutorefresh: TTimer
    Enabled = False
    OnTimer = tmrAutorefreshTimer
    Left = 448
    Top = 16
  end
  object WVBrowser1: TWVBrowser
    TargetCompatibleBrowserVersion = '125.0.2535.41'
    AllowSingleSignOnUsingOSPrimaryAccount = False
    OnInitializationError = WVBrowser1InitializationError
    OnAfterCreated = WVBrowser1AfterCreated
    OnDocumentTitleChanged = WVBrowser1DocumentTitleChanged
    Left = 248
    Top = 216
  end
  object Timer1: TTimer
    Enabled = False
    OnTimer = Timer1Timer
    Left = 184
    Top = 216
  end
end
