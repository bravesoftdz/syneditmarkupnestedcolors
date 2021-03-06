{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynColorFoldHighlighter.pas, released 2015-12-08.
The Original Code is based on the SynHighlighterPas.pas file from the
mwEdit component suite by Martin Waldenburg and other developers, the Initial
Author of this file is x2nie.
All Rights Reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$$

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

Known Issues:
-------------------------------------------------------------------------------}
{
@abstract(Provides a minimum requirement of nested-color-fold highlighter for SynEdit)
@author(Fathony <x2nie AT yahoo DOT com>)
@created(8 Dec 2015)
@lastmod()
The SynColorFoldHighlighter unit can be used as a base for another highlighter
to use together with TSynEditMarkupFoldColors.
}
unit SynColorFoldHighlighter;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, FileUtil, LazUTF8Classes, Graphics,
  SynEditTypes, SynEditHighlighter, SynEditHighlighterFoldBase;

type
  //http://forum.lazarus.freepascal.org/index.php/topic,7338.msg34697.html#msg34697
  {
  You want to look at the procedure SetLine in TSynCustomFoldHighlighter and TSynPasSyn (the pascal highlighter). Maybe also SetRange / ResetRange.
  But ignore all LevelIfDef* / LevelRegion* => the pascal highlighter keeps 3 different set of counters (all using the same logic). This is because ifdef/region can overlap each other.

  Important is that you re-initialize all the fold levels for the line. A line may get scanned more than once, if you do not reset the level, then your results will increase (as you have it).

  There are 2 important counters:
  * FoldEndLevel: Level at the end of line (equals start of next line)                                       = EolFoldLevel
  * FoldMinLevel: Minimum level on this line. This can be lower than the start/end level. See example:       = BolFoldLevel
    begin       // endlevel = 1 ; minlevel = 0
    end  begin // endlevel = 1 ; minlevel = 0
    end         // endlevel = 0 ; minlevel = 0


  LastLineFix will not be needed. it is used where a keyword closes a block. but the close ought to be in the last line (fold-able car/type sections)
    type
       a=integer;  // the fold ends with this line
    var               // but it is only known, when parsing the "var"
       b:a;
  }

{   http://wiki.lazarus.freepascal.org/SynEdit_Highlighter#Step_3:_Add_Folding

  SynEdit's folding is handled by unit SynEditFoldedView and SynGutterCodeFolding. Highlighters that implement folding are to be based on TSynCustomFoldHighlighter.
  The basic information for communication between SynEditFoldedView and the HL
  requires 2 values stored for each line. (Of course the highlighter itself can store more information):
  -  FoldLevel at the end of line
  -  Minimum FoldLevel encountered anywhere on the line
  The Foldlevel indicates how many (nested) folds exist.
  It goes up whenever a fold begins, and down when a fold ends:
                               EndLvl   MinLvl
     Procedure a;               1 -      0
     Begin                      2 --     1 -
       b:= 1;                   2 --     2 --
       if c > b then begin      3 ---    2 --
         c:=b;                  3 ---    3 ---
       end else begin           3 ---    2 --
         b:=c;                  3 ---    3 ---
       end;                     2 --     2 --
     end;                       0        0  // The end closes both: begin and procedure fold

    In the line
     Procedure a;               1 -      0
    the MinLvl is 0, because the line started with a Level of 0 (and it never went down / no folds closed).
    Similar in all lines where there is only an opening fold keyword ("begin").

    But the line
       end else begin           3 ---    2 --
    starts with a level of 3, and also ends with it (one close, one open). But since it went down first, the minimum level encountered anywhere on the line is 2.
    Without the MinLvl it would not be possible to tell that a fold ends in this line.
    There is no such thing as a MaxLvl, because folds that start and end on the same line can not be folded anyway. No need to detect them.
     if a then begin b:=1; c:=2; end; // no fold on that line


}


  { TSynColorFoldHighlighter }

  TSynColorFoldHighlighter = class(TSynCustomFoldHighlighter)
  private
    FCatchNodeInfo: Boolean;
    FCatchNodeInfoList: TLazSynFoldNodeInfoList;
    //function GetPasCodeFoldRange: TSynCustomHighlighterRange;
    procedure MyInitNode(out Node: TSynFoldNodeInfo; SignX, SignX2: Integer;
                       EndOffs: Integer;
                       ABlockType: Integer; aActions: TSynFoldActions;
                       AIsFold: Boolean);

  protected

    procedure InitFoldNodeInfo(AList: TLazSynFoldNodeInfoList; Line: TLineIdx); override;
    // Open/Close Folds
    function StartCodeFoldBlock(SignX,SignX2 : Integer; ABlockType: Pointer=nil;
              IncreaseLevel: Boolean = true): TSynCustomCodeFoldBlock; virtual; reintroduce;
    procedure EndCodeFoldBlock(SignX,SignX2 : Integer;
              DecreaseLevel: Boolean = True); virtual; reintroduce;

  public
    //procedure SetLine(const NewValue: string; LineNumber: Integer); override;

    //function FoldBlockEndLevel(ALineIndex: TLineIdx; const AFilter: TSynFoldBlockFilter): integer; override; overload;
    //function FoldBlockMinLevel(ALineIndex: TLineIdx; const AFilter: TSynFoldBlockFilter): integer; override; overload;
  published
  end;

implementation

uses
  SynEditMiscProcs;



{ TSynColorFoldHighlighter }

procedure TSynColorFoldHighlighter.MyInitNode(out Node: TSynFoldNodeInfo;
  SignX, SignX2: Integer;
  EndOffs: Integer; ABlockType: Integer; aActions: TSynFoldActions;
  AIsFold: Boolean);
var
  OneLine: Boolean;
  i: Integer;
  nd: PSynFoldNodeInfo;
begin
  aActions := aActions + [sfaMultiLine];
  Node.LineIndex := LineIndex;
  Node.LogXStart := SignX;
  Node.LogXEnd := SignX2;
  Node.FoldType := Pointer(PtrInt(ABlockType));
  Node.FoldTypeCompatible := Pointer(PtrInt(ABlockType));//Pointer(PtrInt(PascalFoldTypeCompatibility[ABlockType]));
  Node.FoldAction := aActions;
  node.FoldGroup := 1;//FOLDGROUP_PASCAL;
  if AIsFold then begin
    Node.FoldLvlStart := CodeFoldRange.CodeFoldStackSize;// .PasFoldEndLevel;
    Node.NestLvlStart := CodeFoldRange.CodeFoldStackSize;
    OneLine := (EndOffs < 0) and (Node.FoldLvlStart > CodeFoldRange.MinimumCodeFoldBlockLevel); //.PasFoldMinLevel); //
  end else begin
    Node.FoldLvlStart := CodeFoldRange.CodeFoldStackSize; // Todo: zero?
    Node.NestLvlStart := CodeFoldRange.CodeFoldStackSize;
    OneLine := (EndOffs < 0) and (Node.FoldLvlStart > CodeFoldRange.MinimumCodeFoldBlockLevel);
  end;
  Node.NestLvlEnd := Node.NestLvlStart + EndOffs;
  if not (sfaFold in aActions) then
    EndOffs := 0;
  Node.FoldLvlEnd := Node.FoldLvlStart + EndOffs;
  if OneLine then begin // find opening node
    i := FCatchNodeInfoList.CountAll - 1;
    nd := FCatchNodeInfoList.ItemPointer[i];
    while (i >= 0) and
          ( (nd^.FoldType <> node.FoldType) or
            (nd^.FoldGroup <> node.FoldGroup) or
            (not (sfaOpenFold in nd^.FoldAction)) or
            (nd^.FoldLvlEnd <> Node.FoldLvlStart)
          )
    do begin
      dec(i);
      nd := FCatchNodeInfoList.ItemPointer[i];
    end;
    if i >= 0 then begin
      nd^.FoldAction  := nd^.FoldAction + [sfaOneLineOpen, sfaSingleLine] - [sfaMultiLine];
      Node.FoldAction := Node.FoldAction + [sfaOneLineClose, sfaSingleLine] - [sfaMultiLine];
      if (sfaFoldHide in nd^.FoldAction) then begin
        assert(sfaFold in nd^.FoldAction, 'sfaFoldHide without sfaFold');
        // one liner: hide-able / not fold-able
        nd^.FoldAction  := nd^.FoldAction - [sfaFoldFold];
        Node.FoldAction := Node.FoldAction - [sfaFoldFold];
      end else begin
        // one liner: nether hide-able nore fold-able
        nd^.FoldAction  := nd^.FoldAction - [sfaOpenFold, sfaFold, sfaFoldFold];
        Node.FoldAction := Node.FoldAction - [sfaCloseFold, sfaFold, sfaFoldFold];
      end;
    end;
  end;
  //
end;



procedure TSynColorFoldHighlighter.InitFoldNodeInfo(
  AList: TLazSynFoldNodeInfoList; Line: TLineIdx);
var
  nd: PSynFoldNodeInfo;
  i: Integer;
begin
  FCatchNodeInfo := True;
  FCatchNodeInfoList := TLazSynFoldNodeInfoList(AList);

  StartAtLineIndex(Line);
  //fStringLen := 0;
  NextToEol;

  {fStringLen := 0;
  i := LastLinePasFoldLevelFix(Line+1, FOLDGROUP_PASCAL, True);  // all pascal nodes (incl. not folded)
  while i < 0 do begin
    EndPascalCodeFoldBlock;
    FCatchNodeInfoList.LastItemPointer^.FoldAction :=
      FCatchNodeInfoList.LastItemPointer^.FoldAction + [sfaCloseForNextLine];
    inc(i);
  end;
  if Line = CurrentLines.Count - 1 then begin
    // last line, close all folds
    // Run (for LogXStart) is at line-end
    i := FCatchNodeInfoList.CountAll;
    while TopPascalCodeFoldBlockType <> cfbtNone do
      EndPascalCodeFoldBlock(True);
    while FSynPasRangeInfo.EndLevelIfDef > 0 do
      EndCustomCodeFoldBlock(cfbtIfDef);
    while FSynPasRangeInfo.EndLevelRegion > 0 do
      EndCustomCodeFoldBlock(cfbtRegion);
    while i < FCatchNodeInfoList.CountAll do begin
      nd := FCatchNodeInfoList.ItemPointer[i];
      nd^.FoldAction := nd^.FoldAction + [sfaLastLineClose];
      inc(i);
    end;
  end;}
  FCatchNodeInfo := False;
end;

function TSynColorFoldHighlighter.StartCodeFoldBlock(SignX, SignX2: Integer;
  ABlockType: Pointer; IncreaseLevel: Boolean
  ): TSynCustomCodeFoldBlock;
var
  p: PtrInt;
  FoldBlock, BlockEnabled: Boolean;
  act: TSynFoldActions;
  nd: TSynFoldNodeInfo;
begin
  if FCatchNodeInfo then begin // exclude subblocks, because they do not increase the foldlevel yet
    BlockEnabled := False;//FFoldConfig[PtrInt(ABlockType)].Enabled;
    FoldBlock := True;
    act := [sfaOpen, sfaOpenFold]; //TODO: sfaOpenFold not for cfbtIfThen
    act := act + [sfaFold,  sfaFoldFold, sfaMarkup];//x2nie
    if BlockEnabled then
      act := act + FFoldConfig[longint(ABlockType)].FoldActions;
    //if not FAtLineStart then
      //act := act - [sfaFoldHide];
    MyInitNode(nd, SignX,SignX2, +1, PtrInt(ABlockType), act, FoldBlock);
    FCatchNodeInfoList.Add(nd);
  end;
  result := inherited StartCodeFoldBlock(ABlockType, IncreaseLevel);
end;

procedure TSynColorFoldHighlighter.EndCodeFoldBlock(SignX, SignX2: Integer;
  DecreaseLevel: Boolean);
var
  //DecreaseLevel,
  BlockEnabled: Boolean;
  act: TSynFoldActions;
  BlockType: Integer;
  nd: TSynFoldNodeInfo;
begin
  if FCatchNodeInfo then begin // exclude subblocks, because they do not increase the foldlevel yet
    BlockEnabled := False;// FFoldConfig[PtrInt(BlockType)].Enabled;
    act := [sfaClose, sfaCloseFold];
    act := act + [sfaFold, sfaFoldFold, sfaMarkup];//x2nie
    if BlockEnabled then
      act := act + FFoldConfig[PtrInt(BlockType)].FoldActions - [sfaFoldFold, sfaFoldHide]; // TODO: Why filter?
    if not DecreaseLevel then
      act := act - [sfaFold, sfaFoldFold, sfaFoldHide];
    //if NoMarkup then       exclude(act, sfaMarkup);
    MyInitNode(nd, SignX,SignX2, -1, BlockType, act, DecreaseLevel);
    FCatchNodeInfoList.Add(nd);
  end;
  inherited EndCodeFoldBlock(DecreaseLevel);
end;



end.

