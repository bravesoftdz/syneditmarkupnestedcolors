program IndividualCheck;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, unit2, SynEditMarkupFoldColoring, //SynColorFoldHighlighter,
SynHighlighterBracket, SynGutterFoldDebug
  { you can add units after this };

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
