object WAInsertTableDialog: TWAInsertTableDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Inserir tabela'
  ClientHeight = 165
  ClientWidth = 260
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 15
  object LabelRows: TLabel
    Left = 24
    Top = 20
    Width = 33
    Height = 15
    Caption = 'Linhas'
  end
  object LabelColumns: TLabel
    Left = 24
    Top = 52
    Width = 47
    Height = 15
    Caption = 'Colunas'
  end
  object LabelBorder: TLabel
    Left = 24
    Top = 84
    Width = 68
    Height = 15
    Caption = 'Borda (px)'
  end
  object EditRows: TEdit
    Left = 120
    Top = 17
    Width = 100
    Height = 23
    TabOrder = 0
    Text = '2'
  end
  object EditColumns: TEdit
    Left = 120
    Top = 49
    Width = 100
    Height = 23
    TabOrder = 1
    Text = '2'
  end
  object EditBorder: TEdit
    Left = 120
    Top = 81
    Width = 100
    Height = 23
    TabOrder = 2
    Text = '1'
  end
  object ButtonOK: TButton
    Left = 64
    Top = 124
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 3
    OnClick = ButtonOKClick
  end
  object ButtonCancel: TButton
    Left = 145
    Top = 124
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancelar'
    ModalResult = 2
    TabOrder = 4
  end
end
