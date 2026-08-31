unit WAEditor.Application.ICommand;

interface

type
  /// A single, undoable-by-the-engine formatting action requested by the
  /// user (Command pattern). Concrete commands validate their own
  /// parameters and translate them into calls on IWAHtmlEditorEngine.
  IWAEditorCommand = interface
    ['{6F1B8C9E-2B0C-4E8E-8B3B-2F1B4F0B7C03}']
    procedure Execute;
  end;

implementation

end.
