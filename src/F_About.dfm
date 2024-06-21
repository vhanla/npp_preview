object AboutForm: TAboutForm
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = 'About Preview HTML'
  ClientHeight = 256
  ClientWidth = 300
  ParentFont = True
  Position = poScreenCenter
  OnCreate = FormCreate
  ExplicitHeight = 297
  PixelsPerInch = 96
  TextHeight = 14
  object lblBasedOn: TLabel
    Left = 16
    Top = 96
    Width = 175
    Height = 14
    Caption = 'Based on the example plugin by'
  end
  object lblPlugin: TLabel
    Left = 16
    Top = 8
    Width = 200
    Height = 14
    Caption = 'HTML Preview plugin for Notepad++'
    ShowAccelChar = False
  end
  object lblVersion: TLabel
    Left = 196
    Top = 8
    Width = 46
    Height = 14
    Caption = 'v0.0.0.0'
  end
  object lblAuthor: TLabel
    Left = 16
    Top = 27
    Width = 248
    Height = 18
    Caption = 'by Martijn Coppoolse,'
  end
  object lblAuthorContact: TLabel
    Left = 123
    Top = 27
    Width = 248
    Height = 8
    Cursor = crHandPoint
    Font.Color = clHighlight
    Font.Style = [fsUnderline]
    Font.Height = 14
    Hint = 'mailto:vor0nwe@users.sf.net'
    Caption = 'vor0nwe@users.sf.net'
    OnClick = lblLinkClick
  end
  object lblTribute: TLabel
    Left = 16
    Top = 115
    Width = 227
    Height = 18
    Caption = 'Damjan Zobo Cvetko,'
  end
  object lblTributeContact: TLabel
    Left = 122
    Top = 115
    Width = 227
    Height = 8
    Cursor = crHandPoint
    Font.Color = clHighlight
    Font.Style = [fsUnderline]
    Font.Height = 14
    Hint = 'mailto:zobo@users.sf.net'
    Caption = 'zobo@users.sf.net'
    OnClick = lblLinkClick
  end
  object btnOK: TButton
    Left = 136
    Top = 220
    Width = 75
    Height = 25
    Anchors = [akLeft, akRight, akBottom]
    Cancel = True
    Caption = '&OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
  end
  object lblURL: TLabel
    Left = 16
    Top = 46
    Width = 200
    Height = 8
    Cursor = crHandPoint
    Font.Color = clHighlight
    Font.Style = [fsUnderline]
    Font.Height = 14
    Hint = 'https://fossil.2of4.net/npp_preview'
    Caption = 'https://fossil.2of4.net/npp_preview'
    OnClick = lblLinkClick
  end
  object lblIEVersion: TLabel
    Left = 16
    Top = 160
    Width = 223
    Height = 18
    Caption = 'Internet Explorer version %s is installed.'
  end
end
