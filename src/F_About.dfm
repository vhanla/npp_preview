inherited AboutForm: TAboutForm
  BorderIcons = []
  BorderStyle = bsSizeable
  Caption = 'About Preview HTML'
  ClientHeight = 256
  ParentFont = True
  Position = poDesigned
  OnCreate = FormCreate
  ExplicitHeight = 297
  PixelsPerInch = 96
  TextHeight = 14
  object lblBasedOn: TLabel
    Left = 8
    Top = 96
    Width = 175
    Height = 14
    Caption = 'Based on the example plugin by'
  end
  object lblPlugin: TLabel
    Left = 8
    Top = 8
    Width = 200
    Height = 14
    Caption = 'HTML Preview plugin for Notepad++'
    ShowAccelChar = False
  end
  object lblVersion: TLabel
    Left = 189
    Top = 8
    Width = 46
    Height = 14
    Caption = 'v0.0.0.0'
  end
  object lblAuthor: TLinkLabel
    Left = 8
    Top = 27
    Width = 248
    Height = 18
    Caption = 
      'by Martijn Coppoolse, <a href="mailto:vor0nwe@users.sf.net">vor0' +
      'nwe@users.sf.net</a>'
    TabOrder = 1
    OnLinkClick = lblLinkClick
  end
  object lblTribute: TLinkLabel
    Left = 8
    Top = 115
    Width = 227
    Height = 18
    Caption = 
      'Damjan Zobo Cvetko, <a href="mailto:zobo@users.sf.net">zobo@user' +
      's.sf.net</a>'
    TabOrder = 3
    OnLinkClick = lblLinkClick
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
  object lblURL: TLinkLabel
    Left = 8
    Top = 46
    Width = 200
    Height = 18
    Cursor = crHandPoint
    Caption = 
      '<a href="https://fossil.2of4.net/npp_preview">https://fossil.2of' +
      '4.net/npp_preview</a>'
    TabOrder = 2
    OnLinkClick = lblLinkClick
  end
  object lblIEVersion: TLinkLabel
    Left = 8
    Top = 160
    Width = 223
    Height = 18
    Caption = 'Internet Explorer version %s is installed.'
    TabOrder = 4
  end
end
