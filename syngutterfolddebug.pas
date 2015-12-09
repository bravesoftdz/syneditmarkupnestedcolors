unit SynGutterFoldDebug;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Controls, Graphics, Menus, LCLIntf, SynGutterBase, SynEditMiscProcs,
  SynEditFoldedView, SynEditMouseCmds, SynEditHighlighterFoldBase, LCLProc, LCLType, ImgList;

type

  { TSynGutterFoldDebug }

  TSynGutterFoldDebug = class(TSynGutterPartBase)
  private
    procedure PaintFoldLvl(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);

  public
    constructor Create(AOwner: TComponent); override;
    //destructor Destroy; override;

    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
      override;
  end;

implementation
uses
  SynEdit,SynEditHighlighter,SynTextDrawer,
  SynColorFoldHighlighter;

type
  TSynColorFoldHighlighterAccess = class(TSynColorFoldHighlighter);

{ TSynGutterFoldDebug }

procedure TSynGutterFoldDebug.PaintFoldLvl(Canvas: TCanvas; AClip: TRect;
  FirstLine, LastLine: integer);
var
  TextDrawer: TheTextDrawer;
  c, i, iLine, LineHeight: Integer;
  rcLine: TRect;
  dc: HDC;
  s: String;
  RngLst: TSynHighlighterRangeList;
  r: TSynColorFoldHighlighterRange;//TSynPasSynRange;
  HL : TSynColorFoldHighlighterAccess;
begin
  if TCustomSynEdit(SynEdit).Highlighter = nil then exit;
  if not(TCustomSynEdit(SynEdit).Highlighter is TSynColorFoldHighlighter)  then exit;
  //TCustomSynEdit(SynEdit).Highlighter.CurrentLines := TheLinesView;
  TextDrawer := Gutter.TextDrawer;
  dc := Canvas.Handle;
  //TSynHighlighterPasRangeList
  //mojo
  //woles
  //getuk
  //RngLst := TSynHighlighterRangeList(TheLinesView.Ranges[TCustomSynEdit(SynEdit).Highlighter]);

  HL := TSynColorFoldHighlighterAccess( TCustomSynEdit(self.SynEdit).Highlighter );
  RngLst := HL.CurrentRanges;
  // Clear all
  TextDrawer.BeginDrawing(dc);
  try
    TextDrawer.SetBackColor(Gutter.Color);
    TextDrawer.SetForeColor(TCustomSynEdit(SynEdit).Font.Color);
    TextDrawer.SetFrameColor(clNone);
     with AClip do
       TextDrawer.ExtTextOut(Left, Top, ETO_OPAQUE, AClip, nil, 0);

    rcLine := AClip;
    rcLine.Bottom := AClip.Top;
    LineHeight := TCustomSynEdit(SynEdit).LineHeight;
    c := TCustomSynEdit(SynEdit).Lines.Count;
    for i := FirstLine to LastLine do
    begin
      iLine := FoldView.DisplayNumber[i];
      if (iLine < 0) or (iLine >= c) then break;
      // next line rect
      rcLine.Top := rcLine.Bottom;
      rcLine.Bottom := rcLine.Bottom + LineHeight;

      if iLine > 0 then begin
        r := TSynColorFoldHighlighterRange(RngLst.Range[iLine-1]);
        s:= format('%2d %2d %2d  %2d %2d  ',
                   [r.PasFoldEndLevel, r.PasFoldMinLevel, r.PasFoldFixLevel,
                    r.CodeFoldStackSize, r.MinimumCodeFoldBlockLevel //, r.LastLineCodeFoldLevelFix
                   ]
                  );
      end
      else
        s:= '-';

      TextDrawer.ExtTextOut(rcLine.Left, rcLine.Top, ETO_OPAQUE or ETO_CLIPPED, rcLine,
        PChar(Pointer(S)),Length(S));
    end;

  finally
    TextDrawer.EndDrawing;
  end;

end;

constructor TSynGutterFoldDebug.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  AutoSize := False;
  Width := 200;//PreferedWidth;
end;

procedure TSynGutterFoldDebug.Paint(Canvas: TCanvas; AClip: TRect; FirstLine,
  LastLine: integer);
begin
  Canvas.Pen.Color := clAqua;
  with AClip do
  canvas.Line(left,top,right,bottom);
  PaintFoldLvl(Canvas, AClip, FirstLine, LastLine);
end;

end.
