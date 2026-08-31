object WAMainForm: TWAMainForm
  Left = 0
  Top = 0
  Caption = 'WAEditor'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object ToolbarPanel: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object ButtonBold: TSpeedButton
      Left = 8
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 0
      AllowAllUp = True
      Caption = 'N'
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      OnClick = ButtonBoldClick
    end
    object ButtonItalic: TSpeedButton
      Left = 38
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 0
      AllowAllUp = True
      Caption = 'I'
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsItalic]
      ParentFont = False
      OnClick = ButtonItalicClick
    end
    object ButtonUnderline: TSpeedButton
      Left = 68
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 0
      AllowAllUp = True
      Caption = 'S'
      Flat = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsUnderline]
      ParentFont = False
      OnClick = ButtonUnderlineClick
    end
    object ComboFontName: TComboBox
      Left = 108
      Top = 7
      Width = 160
      Height = 23
      Style = csDropDown
      TabOrder = 0
      Text = 'Segoe UI'
      OnChange = ComboFontNameChange
    end
    object ComboFontSize: TComboBox
      Left = 276
      Top = 7
      Width = 60
      Height = 23
      Style = csDropDownList
      TabOrder = 1
      OnChange = ComboFontSizeChange
      Items.Strings = (
        '8'
        '9'
        '10'
        '11'
        '12'
        '14'
        '16'
        '18'
        '20'
        '24'
        '28'
        '32'
        '36'
        '48')
    end
    object ButtonAlignLeft: TSpeedButton
      Left = 348
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 1
      Down = True
      Caption = 'E'
      Flat = True
      OnClick = ButtonAlignLeftClick
    end
    object ButtonAlignCenter: TSpeedButton
      Left = 378
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 1
      Caption = 'C'
      Flat = True
      OnClick = ButtonAlignCenterClick
    end
    object ButtonAlignRight: TSpeedButton
      Left = 408
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 1
      Caption = 'D'
      Flat = True
      OnClick = ButtonAlignRightClick
    end
    object ButtonAlignJustify: TSpeedButton
      Left = 438
      Top = 6
      Width = 28
      Height = 28
      GroupIndex = 1
      Caption = 'J'
      Flat = True
      OnClick = ButtonAlignJustifyClick
    end
    object ButtonInsertTable: TButton
      Left = 480
      Top = 6
      Width = 110
      Height = 28
      Caption = 'Inserir tabela'
      TabOrder = 2
      OnClick = ButtonInsertTableClick
    end
  end
  object MainMenu1: TMainMenu
    Left = 848
    Top = 8
    object MenuFile: TMenuItem
      Caption = '&Arquivo'
      object MenuFileNew: TMenuItem
        Caption = '&Novo'
        ShortCut = 16462
        OnClick = MenuFileNewClick
      end
      object MenuFileOpen: TMenuItem
        Caption = '&Abrir...'
        ShortCut = 16463
        OnClick = MenuFileOpenClick
      end
      object MenuFileSave: TMenuItem
        Caption = '&Salvar'
        ShortCut = 16467
        OnClick = MenuFileSaveClick
      end
      object MenuFileSaveAs: TMenuItem
        Caption = 'Salvar &como...'
        OnClick = MenuFileSaveAsClick
      end
      object MenuFileSeparator: TMenuItem
        Caption = '-'
      end
      object MenuFileExit: TMenuItem
        Caption = 'Sai&r'
        OnClick = MenuFileExitClick
      end
    end
  end
  object OpenDialog1: TOpenDialog
    Left = 784
    Top = 8
  end
  object SaveDialog1: TSaveDialog
    Left = 816
    Top = 8
  end
end
