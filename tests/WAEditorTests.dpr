program WAEditorTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  WAEditor.Tests.Domain.FontSpecTests in 'Domain\WAEditor.Tests.Domain.FontSpecTests.pas',
  WAEditor.Tests.Domain.TableSpecTests in 'Domain\WAEditor.Tests.Domain.TableSpecTests.pas',
  WAEditor.Tests.Domain.AlignmentMapperTests in 'Domain\WAEditor.Tests.Domain.AlignmentMapperTests.pas',
  WAEditor.Tests.Domain.TableHtmlBuilderTests in 'Domain\WAEditor.Tests.Domain.TableHtmlBuilderTests.pas',
  WAEditor.Tests.Domain.FontSizeScaleTests in 'Domain\WAEditor.Tests.Domain.FontSizeScaleTests.pas',
  WAEditor.Tests.Fakes.FakeHtmlEditorEngine in 'Fakes\WAEditor.Tests.Fakes.FakeHtmlEditorEngine.pas',
  WAEditor.Tests.Fakes.FakeHtmlDocumentStorage in 'Fakes\WAEditor.Tests.Fakes.FakeHtmlDocumentStorage.pas',
  WAEditor.Tests.Application.CommandTests in 'Application\WAEditor.Tests.Application.CommandTests.pas',
  WAEditor.Tests.Application.DocumentServiceTests in 'Application\WAEditor.Tests.Application.DocumentServiceTests.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := True;

    Logger := TDUnitXConsoleLogger.Create(False);
    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(Logger);
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;

    {$IFDEF CI}
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;
    {$ELSE}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      {$IFNDEF CI}
      System.Readln;
      {$ENDIF}
    end;
  end;
end.
