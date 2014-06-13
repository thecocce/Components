{ -------------------------------------------------------------------------------
  The contents of this file are subject to the Mozilla Public License
  Version 1.1 (the "License"); you may not use this file except in compliance
  with the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
  the specific language governing rights and limitations under the License.

  The Original Code is: SynUniHighlighter.pas, released 2003-01
  All Rights Reserved.

  Alternatively, the contents of this file may be used under the terms of the
  GNU General Public License Version 2 or later (the "GPL"), in which case
  the provisions of the GPL are applicable instead of those above.
  If you wish to allow use of your version of this file only under the terms
  of the GPL and not to allow others to use your version of this file
  under the MPL, indicate your decision by deleting the provisions above and
  replace them with the notice and other provisions required by the GPL.
  If you do not delete the provisions above, a recipient may use your version
  of this file under either the MPL or the GPL.

  {
  @abstract(TSynUniSyn parser. Based on TXMLParser)
  @authors(http://www.destructor.de)
  @created(2003)
  @lastmod(2005-07-17)
}

unit SynUniParser;

interface

uses
  SysUtils, Classes,
{$IFDEF HAS_CONTNRS_UNIT}  // The Contnrs Unit was introduced in Delphi 5
  Contnrs,
{$ENDIF}
  Math;

type
  TPartType = // --- Document Part Types
    (ptNone, // Nothing
    ptXmlProlog, // XML Prolog                  XmlSpec 2.8 / 4.3.1
    ptComment, // Comment                     XmlSpec 2.5
    ptPI, // Processing Instruction      XmlSpec 2.6
    ptDtdc, // Document Type Declaration   XmlSpec 2.8
    ptStartTag, // Start Tag                   XmlSpec 3.1
    ptEmptyTag, // Empty-Element Tag           XmlSpec 3.1
    ptEndTag, // End Tag                     XmlSpec 3.1
    ptContent, // Text Content between Tags
    ptCData); // CDATA Section               XmlSpec 2.7

  TDtdElemType = // --- DTD Elements
    (deElement, // !ELEMENT declaration
    deAttList, // !ATTLIST declaration
    deEntity, // !ENTITY declaration
    deNotation, // !NOTATION declaration
    dePI, // PI in DTD
    deComment, // Comment in DTD
    deError); // Error found in the DTD

type
  TAttrList = class;
  TEntityStack = class;
  TNvpList = class;
  TElemDef = class;
  TElemList = class;
  TEntityDef = class;
  TNotationDef = class;

  TDtdElementRec = record // --- This Record is returned by the DTD parser callback function
    Start, final: PWideChar; // Start/End of the Element's Declaration
    case ElementType: TDtdElemType of // Type of the Element
      deElement, // <!ELEMENT>
      deAttList:
        (ElemDef: TElemDef); // <!ATTLIST>
      deEntity:
        (EntityDef: TEntityDef); // <!ENTITY>
      deNotation:
        (NotationDef: TNotationDef); // <!NOTATION>
      dePI:
        (Target: PWideChar; // <?PI ?>
          Content: PWideChar;
          AttrList: TAttrList);
      deError:
        (Pos: PWideChar); // Error
    // deComment : ((No additional fields here));   // <!-- Comment -->
  end;

  TXmlParser = class // --- Internal Properties and Methods
  protected
    FBuffer: PWideChar; // NIL if there is no buffer available
    FBufferSize: INTEGER; // 0 if the buffer is not owned by the Document instance
    FSource: string; // Name of Source of document. Filename for Documents loaded with LoadFromFile

    FXmlVersion: string; // XML version from Document header. Default is '1.0'
    FEncoding: string; // Encoding from Document header. Default is 'UTF-8'
    FStandalone: BOOLEAN; // Standalone declaration from Document header. Default is 'yes'
    FRootName: string; // Name of the Root Element (= DTD name)
    FDtdcFinal: PWideChar; // Pointer to the '>' character terminating the DTD declaration

    FNormalize: BOOLEAN; // If true: Pack Whitespace and don't return empty contents
    EntityStack: TEntityStack; // Entity Stack for Parameter and General Entities
    FCurEncoding: string; // Current Encoding during parsing (always uppercase)

    procedure AnalyzeProlog; // Analyze XML Prolog or Text Declaration
    procedure AnalyzeComment(Start: PWideChar; var Final: PWideChar); // Analyze Comments
    procedure AnalyzePI(Start: PWideChar; var Final: PWideChar); // Analyze Processing Instructions (PI)
    procedure AnalyzeDtdc; // Analyze Document Type Declaration
    procedure AnalyzeDtdElements(Start: PWideChar; var Final: PWideChar); // Analyze DTD declarations
    procedure AnalyzeTag; // Analyze Start/End/Empty-Element Tags
    procedure AnalyzeCData; // Analyze CDATA Sections
    procedure AnalyzeText(var IsDone: BOOLEAN); // Analyze Text Content between Tags
    procedure AnalyzeElementDecl(Start: PWideChar; var Final: PWideChar);
    procedure AnalyzeAttListDecl(Start: PWideChar; var Final: PWideChar);
    procedure AnalyzeEntityDecl(Start: PWideChar; var Final: PWideChar);
    procedure AnalyzeNotationDecl(Start: PWideChar; var Final: PWideChar);

    procedure PushPE(var Start: PWideChar);
    procedure ReplaceCharacterEntities(var Str: string);
    procedure ReplaceParameterEntities(var Str: string);
    procedure ReplaceGeneralEntities(var Str: string);

    function GetDocBuffer: PWideChar; // Returns FBuffer or a pointer to a NUL char if Buffer is empty

  public // --- Document Properties
    property XmlVersion: string read FXmlVersion; // XML version from the Document Prolog
    property Encoding: string read FEncoding; // Document Encoding from Prolog
    property Standalone: BOOLEAN read FStandalone; // Standalone Declaration from Prolog
    property RootName: string read FRootName; // Name of the Root Element
    property Normalize: BOOLEAN read FNormalize write FNormalize; // True if Content is to be normalized
    property Source: string read FSource; // Name of Document Source (Filename)
    property DocBuffer: PWideChar read GetDocBuffer; // Returns document buffer
  public // --- DTD Objects
    Elements: TElemList; // Elements: List of TElemDef (contains Attribute Definitions)
    Entities: TNvpList; // General Entities: List of TEntityDef
    ParEntities: TNvpList; // Parameter Entities: List of TEntityDef
    Notations: TNvpList; // Notations: List of TNotationDef
  public
    constructor Create;
    destructor Destroy; override;

    // --- Document Handling
    function LoadFromFile(Filename: string; FileMode: INTEGER = fmOpenRead or fmShareDenyNone): BOOLEAN;
    // Loads Document from given file
    function LoadFromBuffer(Buffer: PWideChar): BOOLEAN; // Loads Document from another buffer
    procedure SetBuffer(Buffer: PWideChar); // References another buffer
    procedure Clear; // Clear Document

  public
    // --- Scanning through the document
    CurPartType: TPartType; // Current Type
    CurName: string; // Current Name
    CurContent: string; // Current Normalized Content
    CurStart: PWideChar; // Current First character
    CurFinal: PWideChar; // Current Last character
    CurAttr: TAttrList; // Current Attribute List
    property CurEncoding: string read FCurEncoding; // Current Encoding
    procedure StartScan;
    function Scan: BOOLEAN;

    // --- Events / Callbacks
    function LoadExternalEntity(SystemId, PublicId, Notation: string): TXmlParser; virtual;
    function TranslateEncoding(const Source: string): string; virtual;
    procedure DtdElementFound(DtdElementRec: TDtdElementRec); virtual;
  end;

  TValueType = // --- Attribute Value Type
    (vtNormal, // Normal specified Attribute
    vtImplied, // #IMPLIED attribute value
    vtFixed, // #FIXED attribute value
    vtDefault); // Attribute value from default value in !ATTLIST declaration

  TAttrDefault = // --- Attribute Default Type
    (adDefault, // Normal default value
    adRequired, // #REQUIRED attribute
    adImplied, // #IMPLIED attribute
    adFixed); // #FIXED attribute

  TAttrType = // --- Type of attribute
    (atUnknown, // Unknown type
    atCData, // Character data only
    atID, // ID
    atIdRef, // ID Reference
    atIdRefs, // Several ID References, separated by Whitespace
    atEntity, // Name of an unparsed Entity
    atEntities, // Several unparsed Entity names, separated by Whitespace
    atNmToken, // Name Token
    atNmTokens, // Several Name Tokens, separated by Whitespace
    atNotation, // A selection of Notation names (Unparsed Entity)
    atEnumeration); // Enumeration

  TElemType = // --- Element content type
    (etEmpty, // Element is always empty
    etAny, // Element can have any mixture of PCDATA and any elements
    etChildren, // Element must contain only elements
    etMixed); // Mixed PCDATA and elements

{$IFDEF HAS_CONTNRS_UNIT}
  TObjectList = Contnrs.TObjectList; // Re-Export this identifier
{$ELSE}

  TObjectList = class(TList)
    destructor Destroy; override;
    procedure Delete(Index: INTEGER);
    procedure Clear; override;
  end;
{$ENDIF}

  TNvpNode = class // Name-Value Pair Node
    Name: string;
    Value: string;
    constructor Create(TheName: string = ''; TheValue: string = '');
  end;

  TNvpList = class(TObjectList) // Name-Value Pair List
    procedure Add(Node: TNvpNode);
    function Node(Name: string): TNvpNode; overload;
    function Node(Index: INTEGER): TNvpNode; overload;
    function Value(Name: string): string; overload;
    function Value(Index: INTEGER): string; overload;
    function Name(Index: INTEGER): string;
  end;

  TAttr = class(TNvpNode) // Attribute of a Start-Tag or Empty-Element-Tag
    ValueType: TValueType;
    AttrType: TAttrType;
  end;

  TAttrList = class(TNvpList) // List of Attributes
    procedure Analyze(Start: PWideChar; var Final: PWideChar);
  end;

  TEntityStack = class(TObjectList) // Stack where current position is stored before parsing entities
  protected
    Owner: TXmlParser;
  public
    constructor Create(TheOwner: TXmlParser);
    procedure Push(LastPos: PWideChar); overload;
    procedure Push(Instance: TObject; LastPos: PWideChar); overload;
    function Pop: PWideChar; // Returns next char or NIL if EOF is reached. Frees Instance.
  end;

  TAttrDef = class(TNvpNode) // Represents a <!ATTLIST Definition. "Value" is the default value
    TypeDef: string; // Type definition from the DTD
    Notations: string; // Notation List, separated by pipe symbols '|'
    AttrType: TAttrType; // Attribute Type
    DefaultType: TAttrDefault; // Default Type
  end;

  TElemDef = class(TNvpList) // Represents a <!ELEMENT Definition. Is a list of TAttrDef-Nodes
    Name: string; // Element name
    ElemType: TElemType; // Element type
    Definition: string; // Element definition from DTD
  end;

  TElemList = class(TObjectList) // List of TElemDef nodes
    function Node(Name: string): TElemDef;
    procedure Add(Node: TElemDef);
  end;

  TEntityDef = class(TNvpNode) // Represents a <!ENTITY Definition.
    SystemId: string;
    PublicId: string;
    NotationName: string;
  end;

  TNotationDef = class(TNvpNode) // Represents a <!NOTATION Definition. Value is the System ID
    PublicId: string;
  end;

  TCharset = set of AnsiChar;

const
  CWhitespace = [#32, #9, #13, #10]; // Whitespace characters (XmlSpec 2.3)
  CLetter = [#$41 .. #$5A, #$61 .. #$7A, #$C0 .. #$D6, #$D8 .. #$F6, #$F8 .. #$FF];
  CDigit = [#$30 .. #$39];
  CNameChar = CLetter + CDigit + ['.', '-', '_', ':', #$B7];
  CNameStart = CLetter + ['_', ':'];
  CQuoteChar = ['"', ''''];
  CPubidChar = [#32, ^M, ^J, #9, 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '-', '''', '(', ')', '+', ',', '.', '/', ':', '=',
    '?', ';', '!', '*', '#', '@', '$', '_', '%'];

  CDStart = '<![CDATA[';
  CDEnd = ']]>';

  // --- Name Constants for the above enumeration types
  CPartType_Name: array [TPartType] of string = ('', 'XML Prolog', 'Comment', 'PI', 'DTD Declaration', 'Start Tag',
    'Empty Tag', 'End Tag', 'Text', 'CDATA');
  CValueType_Name: array [TValueType] of string = ('Normal', 'Implied', 'Fixed', 'Default');
  CAttrDefault_Name: array [TAttrDefault] of string = ('Default', 'Required', 'Implied', 'Fixed');
  CElemType_Name: array [TElemType] of string = ('Empty', 'Any', 'Childs only', 'Mixed');
  CAttrType_Name: array [TAttrType] of string = ('Unknown', 'CDATA', 'ID', 'IDREF', 'IDREFS', 'ENTITY', 'ENTITIES',
    'NMTOKEN', 'NMTOKENS', 'Notation', 'Enumeration');

function ConvertWs(Source: string; PackWs: BOOLEAN): string; // Convert WS to spaces #x20
procedure SetStringSF(var S: string; BufferStart, BufferFinal: PWideChar); // SetString by Start/Final of buffer
function StrSFPas(Start, Finish: PWideChar): string; // Convert buffer part to Pascal string
function TrimWs(Source: string): string; // Trim Whitespace

function AnsiToUtf8(Source: Ansistring): string; // Convert Win-1252 to UTF-8
function Utf8ToAnsi(Source: string; UnknownChar: AnsiChar = '�'): Ansistring; // Convert UTF-8 to Win-1252

(*
  ===============================================================================================
  TCustomXmlScanner event based component wrapper for TXmlParser
  ===============================================================================================
*)

type
  TCustomXmlScanner = class;
  TXmlPrologEvent = procedure(Sender: TObject; XmlVersion, Encoding: string; Standalone: BOOLEAN) of object;
  TCommentEvent = procedure(Sender: TObject; Comment: string) of object;
  TPIEvent = procedure(Sender: TObject; Target, Content: string; Attributes: TAttrList) of object;
  TDtdEvent = procedure(Sender: TObject; RootElementName: string) of object;
  TStartTagEvent = procedure(Sender: TObject; TagName: string; Attributes: TAttrList) of object;
  TEndTagEvent = procedure(Sender: TObject; TagName: string) of object;
  TContentEvent = procedure(Sender: TObject; Content: string) of object;
  TElementEvent = procedure(Sender: TObject; ElemDef: TElemDef) of object;
  TEntityEvent = procedure(Sender: TObject; EntityDef: TEntityDef) of object;
  TNotationEvent = procedure(Sender: TObject; NotationDef: TNotationDef) of object;
  TErrorEvent = procedure(Sender: TObject; ErrorPos: PWideChar) of object;
  TExternalEvent = procedure(Sender: TObject; SystemId, PublicId, NotationId: string; var Result: TXmlParser) of object;
  TEncodingEvent = function(Sender: TObject; CurrentEncoding, Source: string): string of object;

  TCustomXmlScanner = class(TComponent)
  protected
    FXmlParser: TXmlParser;
    FOnXmlProlog: TXmlPrologEvent;
    FOnComment: TCommentEvent;
    FOnPI: TPIEvent;
    FOnDtdRead: TDtdEvent;
    FOnStartTag: TStartTagEvent;
    FOnEmptyTag: TStartTagEvent;
    FOnEndTag: TEndTagEvent;
    FOnContent: TContentEvent;
    FOnCData: TContentEvent;
    FOnElement: TElementEvent;
    FOnAttList: TElementEvent;
    FOnEntity: TEntityEvent;
    FOnNotation: TNotationEvent;
    FOnDtdError: TErrorEvent;
    FOnLoadExternal: TExternalEvent;
    FOnTranslateEncoding: TEncodingEvent;
    FStopParser: BOOLEAN;
    function GetNormalize: BOOLEAN;
    procedure SetNormalize(Value: BOOLEAN);

    procedure WhenXmlProlog(XmlVersion, Encoding: string; Standalone: BOOLEAN); virtual;
    procedure WhenComment(Comment: string); virtual;
    procedure WhenPI(Target, Content: string; Attributes: TAttrList); virtual;
    procedure WhenDtdRead(RootElementName: string); virtual;
    procedure WhenStartTag(TagName: string; Attributes: TAttrList); virtual;
    procedure WhenEmptyTag(TagName: string; Attributes: TAttrList); virtual;
    procedure WhenEndTag(TagName: string); virtual;
    procedure WhenContent(Content: string); virtual;
    procedure WhenCData(Content: string); virtual;
    procedure WhenElement(ElemDef: TElemDef); virtual;
    procedure WhenAttList(ElemDef: TElemDef); virtual;
    procedure WhenEntity(EntityDef: TEntityDef); virtual;
    procedure WhenNotation(NotationDef: TNotationDef); virtual;
    procedure WhenDtdError(ErrorPos: PWideChar); virtual;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure LoadFromFile(Filename: TFilename); // Load XML Document from file
    procedure LoadFromBuffer(Buffer: PWideChar); // Load XML Document from buffer
    procedure SetBuffer(Buffer: PWideChar); // Refer to Buffer
    function GetFilename: TFilename;

    procedure Execute; // Perform scanning

  protected
    property XmlParser: TXmlParser read FXmlParser;
    property StopParser: BOOLEAN read FStopParser write FStopParser;
    property Filename: TFilename read GetFilename write LoadFromFile;
    property Normalize: BOOLEAN read GetNormalize write SetNormalize;
    property OnXmlProlog: TXmlPrologEvent read FOnXmlProlog write FOnXmlProlog;
    property OnComment: TCommentEvent read FOnComment write FOnComment;
    property OnPI: TPIEvent read FOnPI write FOnPI;
    property OnDtdRead: TDtdEvent read FOnDtdRead write FOnDtdRead;
    property OnStartTag: TStartTagEvent read FOnStartTag write FOnStartTag;
    property OnEmptyTag: TStartTagEvent read FOnEmptyTag write FOnEmptyTag;
    property OnEndTag: TEndTagEvent read FOnEndTag write FOnEndTag;
    property OnContent: TContentEvent read FOnContent write FOnContent;
    property OnCData: TContentEvent read FOnCData write FOnCData;
    property OnElement: TElementEvent read FOnElement write FOnElement;
    property OnAttList: TElementEvent read FOnAttList write FOnAttList;
    property OnEntity: TEntityEvent read FOnEntity write FOnEntity;
    property OnNotation: TNotationEvent read FOnNotation write FOnNotation;
    property OnDtdError: TErrorEvent read FOnDtdError write FOnDtdError;
    property OnLoadExternal: TExternalEvent read FOnLoadExternal write FOnLoadExternal;
    property OnTranslateEncoding: TEncodingEvent read FOnTranslateEncoding write FOnTranslateEncoding;
  end;

  (*
    ===============================================================================================
    IMPLEMENTATION
    ===============================================================================================
  *)

implementation

(*
  ===============================================================================================
  Unicode and UTF-8 stuff
  ===============================================================================================
*)

const
  // --- Character Translation Table for Unicode <-> Win-1252
  WIN1252_UNICODE: array [$00 .. $FF] of WORD = ($0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007, $0008, $0009,
    $000A, $000B, $000C, $000D, $000E, $000F, $0010, $0011, $0012, $0013, $0014, $0015, $0016, $0017, $0018, $0019,
    $001A, $001B, $001C, $001D, $001E, $001F, $0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027, $0028, $0029,
    $002A, $002B, $002C, $002D, $002E, $002F, $0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037, $0038, $0039,
    $003A, $003B, $003C, $003D, $003E, $003F, $0040, $0041, $0042, $0043, $0044, $0045, $0046, $0047, $0048, $0049,
    $004A, $004B, $004C, $004D, $004E, $004F, $0050, $0051, $0052, $0053, $0054, $0055, $0056, $0057, $0058, $0059,
    $005A, $005B, $005C, $005D, $005E, $005F, $0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067, $0068, $0069,
    $006A, $006B, $006C, $006D, $006E, $006F, $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077, $0078, $0079,
    $007A, $007B, $007C, $007D, $007E, $007F,

    $20AC, $0081, $201A, $0192, $201E, $2026, $2020, $2021, $02C6, $2030, $0160, $2039, $0152, $008D, $017D, $008F,
    $0090, $2018, $2019, $201C, $201D, $2022, $2013, $2014, $02DC, $2122, $0161, $203A, $0153, $009D, $017E, $0178,
    $00A0, $00A1, $00A2, $00A3, $00A4, $00A5, $00A6, $00A7, $00A8, $00A9, $00AA, $00AB, $00AC, $00AD, $00AE, $00AF,
    $00B0, $00B1, $00B2, $00B3, $00B4, $00B5, $00B6, $00B7, $00B8, $00B9, $00BA, $00BB, $00BC, $00BD, $00BE, $00BF,
    $00C0, $00C1, $00C2, $00C3, $00C4, $00C5, $00C6, $00C7, $00C8, $00C9, $00CA, $00CB, $00CC, $00CD, $00CE, $00CF,
    $00D0, $00D1, $00D2, $00D3, $00D4, $00D5, $00D6, $00D7, $00D8, $00D9, $00DA, $00DB, $00DC, $00DD, $00DE, $00DF,
    $00E0, $00E1, $00E2, $00E3, $00E4, $00E5, $00E6, $00E7, $00E8, $00E9, $00EA, $00EB, $00EC, $00ED, $00EE, $00EF,
    $00F0, $00F1, $00F2, $00F3, $00F4, $00F5, $00F6, $00F7, $00F8, $00F9, $00FA, $00FB, $00FC, $00FD, $00FE, $00FF);

  (* UTF-8  (somewhat simplified)
    -----
    Character Range    Byte sequence
    ---------------    --------------------------     (x=Bits from original character)
    $0000..$007F       0xxxxxxx
    $0080..$07FF       110xxxxx 10xxxxxx
    $8000..$FFFF       1110xxxx 10xxxxxx 10xxxxxx

    Example
    --------
    Transforming the Unicode character U+00E4 LATIN SMALL LETTER A WITH DIAERESIS  ("�"):

    ISO-8859-1,           Decimal  228
    Win1252,              Hex      $E4
    ANSI                  Bin      1110 0100
    abcd efgh

    UTF-8                 Binary   1100xxab 10cdefgh
    Binary   11000011 10100100
    Hex      $C3      $A4
    Decimal  195      164
    ANSI     �        � *)

function AnsiToUtf8(Source: Ansistring): string;
(* Converts the given Windows ANSI (Win1252) String to UTF-8. *)
var
  I: INTEGER; // Loop counter
  U: WORD; // Current Unicode value
  Len: INTEGER; // Current real length of "Result" string
begin
  SetLength(Result, Length(Source) * 3); // Worst case
  Len := 0;
  for I := 1 to Length(Source) do
  begin
    U := WIN1252_UNICODE[ORD(Source[I])];
    case U of
      $0000 .. $007F:
        begin
          INC(Len);
          Result[Len] := CHR(U);
        end;
      $0080 .. $07FF:
        begin
          INC(Len);
          Result[Len] := CHR($C0 or (U shr 6));
          INC(Len);
          Result[Len] := CHR($80 or (U and $3F));
        end;
      $0800 .. $FFFF:
        begin
          INC(Len);
          Result[Len] := CHR($E0 or (U shr 12));
          INC(Len);
          Result[Len] := CHR($80 or ((U shr 6) and $3F));
          INC(Len);
          Result[Len] := CHR($80 or (U and $3F));
        end;
    end;
  end;
  SetLength(Result, Len);
end;

function Utf8ToAnsi(Source: string; UnknownChar: AnsiChar = '�'): Ansistring;
(* Converts the given UTF-8 String to Windows ANSI (Win-1252).
  If a character can not be converted, the "UnknownChar" is inserted. *)
var
  SourceLen: INTEGER; // Length of Source string
  I, K: INTEGER;
  A: Byte; // Current ANSI character value
  U: WORD;
  Ch: AnsiChar; // Dest char
  Len: INTEGER; // Current real length of "Result" string
begin
  SourceLen := Length(Source);
  SetLength(Result, SourceLen); // Enough room to live
  Len := 0;
  I := 1;
  while I <= SourceLen do
  begin
    A := ORD(Source[I]);
    if A < $80 then
    begin // Range $0000..$007F
      INC(Len);
      Result[Len] := AnsiChar(Source[I]);
      INC(I);
    end
    else
    begin // Determine U, Inc I
      if (A and $E0 = $C0) and (I < SourceLen) then
      begin // Range $0080..$07FF
        U := (WORD(A and $1F) shl 6) or (ORD(Source[I + 1]) and $3F);
        INC(I, 2);
      end
      else if (A and $F0 = $E0) and (I < SourceLen - 1) then
      begin // Range $0800..$FFFF
        U := (WORD(A and $0F) shl 12) or (WORD(ORD(Source[I + 1]) and $3F) shl 6) or (ORD(Source[I + 2]) and $3F);
        INC(I, 3);
      end
      else
      begin // Unknown/unsupported
        INC(I);
        for K := 7 downto 0 do
          if A and (1 shl K) = 0 then
          begin
            INC(I, (A shr (K + 1)) - 1);
            Break;
          end;
        U := WIN1252_UNICODE[ORD(UnknownChar)];
      end;
      Ch := UnknownChar; // Retrieve ANSI char
      for A := $00 to $FF do
        if WIN1252_UNICODE[A] = U then
        begin
          Ch := AnsiChar(CHR(A));
          Break;
        end;
      INC(Len);
      Result[Len] := Ch;
    end;
  end;
  SetLength(Result, Len);
end;

(*
  ===============================================================================================
  "Special" Helper Functions

  Don't ask me why. But including these functions makes the parser *DRAMATICALLY* faster
  on my K6-233 machine. You can test it yourself just by commenting them out.
  They do exactly the same as the Assembler routines defined in SysUtils.
  (This is where you can see how great the Delphi compiler really is. The compiled code is
  faster than hand-coded assembler!)
  ===============================================================================================
  --> Just move this line below the StrScan function --> *)

function StrPos(const Str, SearchStr: PWideChar): PWideChar;
// Same functionality as SysUtils.StrPos
var
  First: WideChar;
  Len: INTEGER;
begin
  First := SearchStr^;
  Len := StrLen(SearchStr);
  Result := Str;
  repeat
    if Result^ = First then
      if StrLComp(Result, SearchStr, Len) = 0 then
        Break;
    if Result^ = #0 then
    begin
      Result := nil;
      Break;
    end;
    INC(Result);
  until FALSE;
end;

function StrScan(const Start: PWideChar; const Ch: WideChar): PWideChar;
// Same functionality as SysUtils.StrScan
begin
  Result := Start;
  while Result^ <> Ch do
  begin
    if Result^ = #0 then
    begin
      Result := nil;
      EXIT;
    end;
    INC(Result);
  end;
end;

(*
  ===============================================================================================
  Helper Functions
  ===============================================================================================
*)

function DelChars(Source: string; CharsToDelete: TCharset): string;
// Delete all "CharsToDelete" from the string
var
  I: INTEGER;
begin
  Result := Source;
  for I := Length(Result) downto 1 do
    if CharInSet(Result[I], CharsToDelete) then
      Delete(Result, I, 1);
end;

function TrimWs(Source: string): string;
// Trimms off Whitespace characters from both ends of the string
var
  I: INTEGER;
begin
  // --- Trim Left
  I := 1;
  while (I <= Length(Source)) and CharInSet(Source[I], CWhitespace) do
    INC(I);
  Result := Copy(Source, I, MaxInt);

  // --- Trim Right
  I := Length(Result);
  while (I > 1) and CharInSet(Result[I], CWhitespace) do
    DEC(I);
  Delete(Result, I + 1, Length(Result) - I);
end;

function ConvertWs(Source: string; PackWs: BOOLEAN): string;
// Converts all Whitespace characters to the Space #x20 character
// If "PackWs" is true, contiguous Whitespace characters are packed to one
var
  I: INTEGER;
begin
  Result := Source;
  for I := Length(Result) downto 1 do
    if CharInSet(Result[I], CWhitespace) then
      if PackWs and (I > 1) and CharInSet(Result[I - 1], CWhitespace) then
        Delete(Result, I, 1)
      else
        Result[I] := #32;
end;

procedure SetStringSF(var S: string; BufferStart, BufferFinal: PWideChar);
begin
  SetString(S, BufferStart, BufferFinal - BufferStart + 1);
end;

function StrLPas(Start: PWideChar; Len: INTEGER): string;
begin
  SetString(Result, Start, Len);
end;

function StrSFPas(Start, Finish: PWideChar): string;
begin
  SetString(Result, Start, Finish - Start + 1);
end;

function StrScanE(const Source: PWideChar; const CharToScanFor: WideChar): PWideChar;
// If "CharToScanFor" is not found, StrScanE returns the last char of the
// buffer instead of NIL
begin
  Result := StrScan(Source, CharToScanFor);
  if Result = nil then
    Result := StrEnd(Source) - 1;
end;

procedure ExtractName(Start: PWideChar; Terminators: TCharset; var Final: PWideChar);
(* Extracts the complete Name beginning at "Start".
  It is assumed that the name is contained in Markup, so the '>' character is
  always a Termination.
  Start:       IN  Pointer to first char of name. Is always considered to be valid
  Terminators: IN  Characters which terminate the name
  Final:       OUT Pointer to last char of name *)
begin
  final := Start + 1;
  Include(Terminators, #0);
  Include(Terminators, '>');
  while not CharInSet(final^, Terminators) do
    INC(final);
  DEC(final);
end;

procedure ExtractQuote(Start: PWideChar; var Content: string; var Final: PWideChar);
(* Extract a string which is contained in single or double Quotes.
  Start:    IN   Pointer to opening quote
  Content:  OUT  The quoted string
  Final:    OUT  Pointer to closing quote *)
begin
  final := StrScan(Start + 1, Start^);
  if final = nil then
  begin
    final := StrEnd(Start + 1) - 1;
    SetString(Content, Start + 1, final - Start);
  end
  else
    SetString(Content, Start + 1, final - 1 - Start);
end;

(*
  ===============================================================================================
  TEntityStackNode
  This Node is pushed to the "Entity Stack" whenever the parser parses entity replacement text.
  The "Instance" field holds the Instance pointer of an External Entity buffer. When it is
  popped, the Instance is freed.
  The "Encoding" field holds the name of the Encoding. External Parsed Entities may have
  another encoding as the document entity (XmlSpec 4.3.3). So when there is an "<?xml" PI
  found in the stream (= Text Declaration at the beginning of external parsed entities), the
  Encoding found there is used for the External Entity (is assigned to TXmlParser.CurEncoding)
  Default Encoding is for the Document Entity is UTF-8. It is assumed that External Entities
  have the same Encoding as the Document Entity, unless they carry a Text Declaration.
  ===============================================================================================
*)

type
  TEntityStackNode = class
    Instance: TObject;
    Encoding: string;
    LastPos: PWideChar;
  end;

  (*
    ===============================================================================================
    TEntityStack
    For nesting of Entities.
    When there is an entity reference found in the data stream, the corresponding entity
    definition is searched and the current position is pushed to this stack.
    From then on, the program scans the entitiy replacement text as if it were normal content.
    When the parser reaches the end of an entity, the current position is popped off the
    stack again.
    ===============================================================================================
  *)

constructor TEntityStack.Create(TheOwner: TXmlParser);
begin
  inherited Create;
  Owner := TheOwner;
end;

procedure TEntityStack.Push(LastPos: PWideChar);
begin
  Push(nil, LastPos);
end;

procedure TEntityStack.Push(Instance: TObject; LastPos: PWideChar);
var
  ESN: TEntityStackNode;
begin
  ESN := TEntityStackNode.Create;
  ESN.Instance := Instance;
  ESN.Encoding := Owner.FCurEncoding; // Save current Encoding
  ESN.LastPos := LastPos;
  Add(ESN);
end;

function TEntityStack.Pop: PWideChar;
var
  ESN: TEntityStackNode;
begin
  if Count > 0 then
  begin
    ESN := TEntityStackNode(Items[Count - 1]);
    Result := ESN.LastPos;
    if ESN.Instance <> nil then
      ESN.Instance.Free;
    if ESN.Encoding <> '' then
      Owner.FCurEncoding := ESN.Encoding; // Restore current Encoding
    Delete(Count - 1);
  end
  else
    Result := nil;
end;

(*
  ===============================================================================================
  TExternalID
  -----------
  XmlSpec 4.2.2:  ExternalID ::= 'SYSTEM' S SystemLiteral |
  'PUBLIC' S PubidLiteral S SystemLiteral
  XmlSpec 4.7:    PublicID   ::= 'PUBLIC' S PubidLiteral
  SystemLiteral and PubidLiteral are quoted
  ===============================================================================================
*)

type
  TExternalID = class
    PublicId: string;
    SystemId: string;
    Final: PWideChar;
    constructor Create(Start: PWideChar);
  end;

constructor TExternalID.Create(Start: PWideChar);
begin
  inherited Create;
  final := Start;
  if StrLComp(Start, 'SYSTEM', 6) = 0 then
  begin
    while not CharInSet(final^, (CQuoteChar + [#0, '>', '['])) do
      INC(final);
    if not CharInSet(final^, CQuoteChar) then
      EXIT;
    ExtractQuote(final, SystemId, final);
  end
  else if StrLComp(Start, 'PUBLIC', 6) = 0 then
  begin
    while not CharInSet(final^, (CQuoteChar + [#0, '>', '['])) do
      INC(final);
    if not CharInSet(final^, CQuoteChar) then
      EXIT;
    ExtractQuote(final, PublicId, final);
    INC(final);
    while not CharInSet(final^, (CQuoteChar + [#0, '>', '['])) do
      INC(final);
    if not CharInSet(final^, CQuoteChar) then
      EXIT;
    ExtractQuote(final, SystemId, final);
  end;
end;

(*
  ===============================================================================================
  TXmlParser
  ===============================================================================================
*)

constructor TXmlParser.Create;
begin
  inherited Create;
  FBuffer := nil;
  FBufferSize := 0;
  Elements := TElemList.Create;
  Entities := TNvpList.Create;
  ParEntities := TNvpList.Create;
  Notations := TNvpList.Create;
  CurAttr := TAttrList.Create;
  EntityStack := TEntityStack.Create(Self);
  Clear;
end;

destructor TXmlParser.Destroy;
begin
  Clear;
  Elements.Free;
  Entities.Free;
  ParEntities.Free;
  Notations.Free;
  CurAttr.Free;
  EntityStack.Free;
  inherited Destroy;
end;

procedure TXmlParser.Clear;
// Free Buffer and clear all object attributes
begin
  if (FBufferSize > 0) and (FBuffer <> nil) then
    FreeMem(FBuffer);
  FBuffer := nil;
  FBufferSize := 0;
  FSource := '';
  FXmlVersion := '';
  FEncoding := '';
  FStandalone := FALSE;
  FRootName := '';
  FDtdcFinal := nil;
  FNormalize := TRUE;
  Elements.Clear;
  Entities.Clear;
  ParEntities.Clear;
  Notations.Clear;
  CurAttr.Clear;
  EntityStack.Clear;
end;

function TXmlParser.LoadFromFile(Filename: string; FileMode: INTEGER = fmOpenRead or fmShareDenyNone): BOOLEAN;
// Loads Document from given file
// Returns TRUE if successful
var
  f: file;
  ReadIn: INTEGER;
  OldFileMode: INTEGER;
begin
  Result := FALSE;
  Clear;

  // --- Open File
  OldFileMode := SYSTEM.FileMode;
  try
    SYSTEM.FileMode := FileMode;
    try
      AssignFile(f, Filename);
      Reset(f, 1);
    except
      EXIT;
    end;

    try
      // --- Allocate Memory
      try
        FBufferSize := Filesize(f) + 1;
        GetMem(FBuffer, FBufferSize);
      except
        Clear;
        EXIT;
      end;

      // --- Read File
      try
        BlockRead(f, FBuffer^, FBufferSize, ReadIn);
        (FBuffer + ReadIn)^ := #0; // NULL termination
      except
        Clear;
        EXIT;
      end;
    finally
      CloseFile(f);
    end;

    FSource := Filename;
    Result := TRUE;

  finally
    SYSTEM.FileMode := OldFileMode;
  end;
end;

function TXmlParser.LoadFromBuffer(Buffer: PWideChar): BOOLEAN;
// Loads Document from another buffer
// Returns TRUE if successful
// The "Source" property becomes '<MEM>' if successful
begin
  Result := FALSE;
  Clear;
  FBufferSize := StrLen(Buffer) + 1;
  try
    GetMem(FBuffer, FBufferSize);
  except
    Clear;
    EXIT;
  end;
  StrCopy(FBuffer, Buffer);
  FSource := '<MEM>';
  Result := TRUE;
end;

procedure TXmlParser.SetBuffer(Buffer: PWideChar); // References another buffer
begin
  Clear;
  FBuffer := Buffer;
  FBufferSize := 0;
  FSource := '<REFERENCE>';
end;


// -----------------------------------------------------------------------------------------------
// Scanning through the document
// -----------------------------------------------------------------------------------------------

procedure TXmlParser.StartScan;
begin
  CurPartType := ptNone;
  CurName := '';
  CurContent := '';
  CurStart := nil;
  CurFinal := nil;
  CurAttr.Clear;
  EntityStack.Clear;
end;

function TXmlParser.Scan: BOOLEAN;
// Scans the next Part
// Returns TRUE if a part could be found, FALSE if there is no part any more
//
// "IsDone" can be set to FALSE by AnalyzeText in order to go to the next part
// if there is no Content due to normalization
var
  IsDone: BOOLEAN;
begin
  repeat
    IsDone := TRUE;

    // --- Start of next Part
    if CurStart = nil then
      CurStart := DocBuffer
    else
      CurStart := CurFinal + 1;
    CurFinal := CurStart;

    // --- End of Document of Pop off a new part from the Entity stack?
    if CurStart^ = #0 then
      CurStart := EntityStack.Pop;

    // --- No Document or End Of Document: Terminate Scan
    if (CurStart = nil) or (CurStart^ = #0) then
    begin
      CurStart := StrEnd(DocBuffer);
      CurFinal := CurStart - 1;
      EntityStack.Clear;
      Result := FALSE;
      EXIT;
    end;

    if (StrLComp(CurStart, '<?xml', 5) = 0) and CharInSet((CurStart + 5)^, CWhitespace) then
      AnalyzeProlog // XML Declaration, Text Declaration
    else if StrLComp(CurStart, '<?', 2) = 0 then
      AnalyzePI(CurStart, CurFinal) // PI
    else if StrLComp(CurStart, '<!--', 4) = 0 then
      AnalyzeComment(CurStart, CurFinal) // Comment
    else if StrLComp(CurStart, '<!DOCTYPE', 9) = 0 then
      AnalyzeDtdc // DTDc
    else if StrLComp(CurStart, CDStart, Length(CDStart)) = 0 then
      AnalyzeCData // CDATA Section
    else if StrLComp(CurStart, '<', 1) = 0 then
      AnalyzeTag // Start-Tag, End-Tag, Empty-Element-Tag
    else
      AnalyzeText(IsDone); // Text Content
  until IsDone;
  Result := TRUE;
end;

procedure TXmlParser.AnalyzeProlog;
// Analyze XML Prolog or Text Declaration
var
  f: PWideChar;
begin
  CurAttr.Analyze(CurStart + 5, f);
  if EntityStack.Count = 0 then
  begin
    FXmlVersion := CurAttr.Value('version');
    FEncoding := CurAttr.Value('encoding');
    FStandalone := CurAttr.Value('standalone') = 'yes';
  end;
  CurFinal := StrPos(f, '?>');
  if CurFinal <> nil then
    INC(CurFinal)
  else
    CurFinal := StrEnd(CurStart) - 1;
  FCurEncoding := AnsiUpperCase(CurAttr.Value('encoding'));
  if FCurEncoding = '' then
    FCurEncoding := 'UTF-8'; // Default XML Encoding is UTF-8
  CurPartType := ptXmlProlog;
  CurName := '';
  CurContent := '';
end;

procedure TXmlParser.AnalyzeComment(Start: PWideChar; var Final: PWideChar);
// Analyze Comments
begin
  final := StrPos(Start + 4, '-->');
  if final = nil then
    final := StrEnd(Start) - 1
  else
    INC(final, 2);
  CurPartType := ptComment;
end;

procedure TXmlParser.AnalyzePI(Start: PWideChar; var Final: PWideChar);
// Analyze Processing Instructions (PI)
// This is also called for Character
var
  f: PWideChar;
begin
  CurPartType := ptPI;
  final := StrPos(Start + 2, '?>');
  if final = nil then
    final := StrEnd(Start) - 1
  else
    INC(final);
  ExtractName(Start + 2, CWhitespace + ['?', '>'], f);
  SetStringSF(CurName, Start + 2, f);
  SetStringSF(CurContent, f + 1, final - 2);
  CurAttr.Analyze(f + 1, f);
end;

procedure TXmlParser.AnalyzeDtdc;
(* Analyze Document Type Declaration
  doctypedecl  ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' (markupdecl | PEReference | S)* ']' S?)? '>'
  markupdecl   ::= elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment
  PEReference  ::= '%' Name ';'

  elementdecl  ::= '<!ELEMENT' S Name S contentspec S?                    '>'
  AttlistDecl  ::= '<!ATTLIST' S Name AttDef* S?                          '>'
  EntityDecl   ::= '<!ENTITY' S Name S EntityDef S?                       '>' |
  '<!ENTITY' S '%' S Name S PEDef S?                     '>'
  NotationDecl ::= '<!NOTATION' S Name S (ExternalID |  PublicID) S?      '>'
  PI           ::=  '<?' PITarget (S (Char* - (Char* '?>' Char* )))?     '?>'
  Comment      ::= '<!--' ((Char - '-') | ('-' (Char - '-')))*          '-->' *)
type
  TPhase = (phName, phDtd, phInternal, phFinishing);
var
  Phase: TPhase;
  f: PWideChar;
  ExternalID: TExternalID;
  ExternalDTD: TXmlParser;
  DER: TDtdElementRec;
begin
  DER.Start := CurStart;
  EntityStack.Clear; // Clear stack for Parameter Entities
  CurPartType := ptDtdc;

  // --- Don't read DTDc twice
  if FDtdcFinal <> nil then
  begin
    CurFinal := FDtdcFinal;
    EXIT;
  end;

  // --- Scan DTDc
  CurFinal := CurStart + 9; // First char after '<!DOCTYPE'
  Phase := phName;
  repeat
    case CurFinal^ of
      '%':
        begin
          PushPE(CurFinal);
          CONTINUE;
        end;
      #0:
        if EntityStack.Count = 0 then
          Break
        else
        begin
          CurFinal := EntityStack.Pop;
          CONTINUE;
        end;
      '[':
        begin
          Phase := phInternal;
          AnalyzeDtdElements(CurFinal + 1, CurFinal);
          CONTINUE;
        end;
      ']':
        Phase := phFinishing;
      '>':
        Break;
    else
      if not CharInSet(CurFinal^, CWhitespace) then
      begin
        case Phase of
          phName:
            if CharInSet(CurFinal^, CNameStart) then
            begin
              ExtractName(CurFinal, CWhitespace + ['[', '>'], f);
              SetStringSF(FRootName, CurFinal, f);
              CurFinal := f;
              Phase := phDtd;
            end;
          phDtd:
            if (StrLComp(CurFinal, 'SYSTEM', 6) = 0) or (StrLComp(CurFinal, 'PUBLIC', 6) = 0) then
            begin
              ExternalID := TExternalID.Create(CurFinal);
              ExternalDTD := LoadExternalEntity(ExternalID.SystemId, ExternalID.PublicId, '');
              f := StrPos(ExternalDTD.DocBuffer, '<!');
              if f <> nil then
                AnalyzeDtdElements(f, f);
              ExternalDTD.Free;
              CurFinal := ExternalID.Final;
              ExternalID.Free;
            end;
        else
          begin
            DER.ElementType := deError;
            DER.Pos := CurFinal;
            DER.Final := CurFinal;
            DtdElementFound(DER);
          end;
        end;

      end;
    end;
    INC(CurFinal);
  until FALSE;

  CurPartType := ptDtdc;
  CurName := '';
  CurContent := '';

  // It is an error in the document if "EntityStack" is not empty now
  if EntityStack.Count > 0 then
  begin
    DER.ElementType := deError;
    DER.Final := CurFinal;
    DER.Pos := CurFinal;
    DtdElementFound(DER);
  end;

  EntityStack.Clear; // Clear stack for General Entities
  FDtdcFinal := CurFinal;
end;

procedure TXmlParser.AnalyzeDtdElements(Start: PWideChar; var Final: PWideChar);
// Analyze the "Elements" of a DTD contained in the external or
// internal DTD subset.
var
  DER: TDtdElementRec;
begin
  final := Start;
  repeat
    case final^ of
      '%':
        begin
          PushPE(final);
          CONTINUE;
        end;
      #0:
        if EntityStack.Count = 0 then
          Break
        else
        begin
          CurFinal := EntityStack.Pop;
          CONTINUE;
        end;
      ']', '>':
        Break;
      '<':
        if StrLComp(final, '<!ELEMENT', 9) = 0 then
          AnalyzeElementDecl(final, final)
        else if StrLComp(final, '<!ATTLIST', 9) = 0 then
          AnalyzeAttListDecl(final, final)
        else if StrLComp(final, '<!ENTITY', 8) = 0 then
          AnalyzeEntityDecl(final, final)
        else if StrLComp(final, '<!NOTATION', 10) = 0 then
          AnalyzeNotationDecl(final, final)
        else if StrLComp(final, '<?', 2) = 0 then
        begin // PI in DTD
          DER.ElementType := dePI;
          DER.Start := final;
          AnalyzePI(final, final);
          DER.Target := PWideChar(CurName);
          DER.Content := PWideChar(CurContent);
          DER.AttrList := CurAttr;
          DER.Final := final;
          DtdElementFound(DER);
        end
        else if StrLComp(final, '<!--', 4) = 0 then
        begin // Comment in DTD
          DER.ElementType := deComment;
          DER.Start := final;
          AnalyzeComment(final, final);
          DER.Final := final;
          DtdElementFound(DER);
        end
        else
        begin
          DER.ElementType := deError;
          DER.Start := final;
          DER.Pos := final;
          DER.Final := final;
          DtdElementFound(DER);
        end;

    end;
    INC(final);
  until FALSE;
end;

procedure TXmlParser.AnalyzeTag;
// Analyze Tags
var
  S, f: PWideChar;
  Attr: TAttr;
  ElemDef: TElemDef;
  AttrDef: TAttrDef;
  I: INTEGER;
begin
  CurPartType := ptStartTag;
  S := CurStart + 1;
  if S^ = '/' then
  begin
    CurPartType := ptEndTag;
    INC(S);
  end;
  ExtractName(S, CWhitespace + ['/'], f);
  SetStringSF(CurName, S, f);
  CurAttr.Analyze(f + 1, CurFinal);
  if CurFinal^ = '/' then
  begin
    CurPartType := ptEmptyTag;
  end;
  CurFinal := StrScanE(CurFinal, '>');

  // --- Set Default Attribute values for nonexistent attributes
  if (CurPartType = ptStartTag) or (CurPartType = ptEmptyTag) then
  begin
    ElemDef := Elements.Node(CurName);
    if ElemDef <> nil then
    begin
      for I := 0 to ElemDef.Count - 1 do
      begin
        AttrDef := TAttrDef(ElemDef[I]);
        Attr := TAttr(CurAttr.Node(AttrDef.Name));
        if (Attr = nil) and (AttrDef.Value <> '') then
        begin
          Attr := TAttr.Create(AttrDef.Name, AttrDef.Value);
          Attr.ValueType := vtDefault;
          CurAttr.Add(Attr);
        end;
        if Attr <> nil then
        begin
          case AttrDef.DefaultType of
            adDefault:
              ;
            adRequired:
              ; // -!- It is an error in the document if "Attr.Value" is an empty string
            adImplied:
              Attr.ValueType := vtImplied;
            adFixed:
              begin
                Attr.ValueType := vtFixed;
                Attr.Value := AttrDef.Value;
              end;
          end;
          Attr.AttrType := AttrDef.AttrType;
        end;
      end;
    end;

    // --- Normalize Attribute Values. XmlSpec:
    // - a character reference is processed by appending the referenced character to the attribute value
    // - an entity reference is processed by recursively processing the replacement text of the entity
    // - a whitespace character (#x20, #xD, #xA, #x9) is processed by appending #x20 to the normalized value,
    // except that only a single #x20 is appended for a "#xD#xA" sequence that is part of an external
    // parsed entity or the literal entity value of an internal parsed entity
    // - other characters are processed by appending them to the normalized value
    // If the declared value is not CDATA, then the XML processor must further process the
    // normalized attribute value by discarding any leading and trailing space (#x20) characters,
    // and by replacing sequences of space (#x20) characters by a single space (#x20) character.
    // All attributes for which no declaration has been read should be treated by a
    // non-validating parser as if declared CDATA.
    // !!! The XML 1.0 SE specification is somewhat different here
    // This code does not conform exactly to this specification
    for I := 0 to CurAttr.Count - 1 do
      with TAttr(CurAttr[I]) do
      begin
        ReplaceGeneralEntities(Value);
        ReplaceCharacterEntities(Value);
        if (AttrType <> atCData) and (AttrType <> atUnknown) then
          Value := TranslateEncoding(TrimWs(ConvertWs(Value, TRUE)))
        else
          Value := TranslateEncoding(ConvertWs(Value, FALSE));
      end;
  end;
end;

procedure TXmlParser.AnalyzeCData;
// Analyze CDATA Sections
begin
  CurPartType := ptCData;
  CurFinal := StrPos(CurStart, CDEnd);
  if CurFinal = nil then
  begin
    CurFinal := StrEnd(CurStart) - 1;
    CurContent := TranslateEncoding(StrPas(CurStart + Length(CDStart)));
  end
  else
  begin
    SetStringSF(CurContent, CurStart + Length(CDStart), CurFinal - 1);
    INC(CurFinal, Length(CDEnd) - 1);
    CurContent := TranslateEncoding(CurContent);
  end;
end;

procedure TXmlParser.AnalyzeText(var IsDone: BOOLEAN);
(* Analyzes Text Content between Tags. CurFinal will point to the last content character.
  Content ends at a '<' character or at the end of the document.
  Entity References and Character Entity references are resolved.
  If PackSpaces is TRUE, contiguous Whitespace Characters will be compressed to
  one Space #x20 character, Whitespace at the beginning and end of content will
  be trimmed off and content which is or becomes empty is not returned to
  the application (in this case, "IsDone" is set to FALSE which causes the
  Scan method to proceed directly to the next part. *)

  procedure ProcessEntity;
  (* Is called if there is an ampsersand '&' character found in the document.
    IN  "CurFinal" points to the ampersand
    OUT "CurFinal" points to the first character after the semi-colon ';' *)
  var
    P: PWideChar;
    Name: string;
    EntityDef: TEntityDef;
    ExternalEntity: TXmlParser;
  begin
    P := StrScan(CurFinal, ';');
    if P <> nil then
    begin
      SetStringSF(name, CurFinal + 1, P - 1);

      // Is it a Character Entity?
      if (CurFinal + 1)^ = '#' then
      begin
        if UpCase((CurFinal + 2)^) = 'X' // !!! Can't use "CHR" for Unicode characters > 255:
        then
          CurContent := CurContent + CHR(StrToIntDef('$' + Copy(name, 3, MaxInt), 32))
        else
          CurContent := CurContent + CHR(StrToIntDef(Copy(name, 2, MaxInt), 32));
        CurFinal := P + 1;
        EXIT;
      end

      // Is it a Predefined Entity?
      else if name = 'lt' then
      begin
        CurContent := CurContent + '<';
        CurFinal := P + 1;
        EXIT;
      end
      else if name = 'gt' then
      begin
        CurContent := CurContent + '>';
        CurFinal := P + 1;
        EXIT;
      end
      else if name = 'amp' then
      begin
        CurContent := CurContent + '&';
        CurFinal := P + 1;
        EXIT;
      end
      else if name = 'apos' then
      begin
        CurContent := CurContent + '''';
        CurFinal := P + 1;
        EXIT;
      end
      else if name = 'quot' then
      begin
        CurContent := CurContent + '"';
        CurFinal := P + 1;
        EXIT;
      end
      else if name = 'qt' then
      begin
        CurContent := CurContent + '"';
        CurFinal := P + 1;
        EXIT;
      end;

      // Replace with Entity from DTD
      EntityDef := TEntityDef(Entities.Node(name));
      if EntityDef <> nil then
      begin
        if EntityDef.Value <> '' then
        begin
          EntityStack.Push(P + 1);
          CurFinal := PWideChar(EntityDef.Value);
        end
        else
        begin
          ExternalEntity := LoadExternalEntity(EntityDef.SystemId, EntityDef.PublicId, EntityDef.NotationName);
          EntityStack.Push(ExternalEntity, P + 1);
          CurFinal := ExternalEntity.DocBuffer;
        end;
      end
      else
      begin
        CurContent := CurContent + name;
        CurFinal := P + 1;
      end;
    end
    else
    begin
      INC(CurFinal);
    end;
  end;

var
  C: INTEGER;
begin
  CurFinal := CurStart;
  CurPartType := ptContent;
  CurContent := '';
  C := 0;
  repeat
    case CurFinal^ of
      '&':
        begin
          CurContent := CurContent + TranslateEncoding(StrLPas(CurFinal - C, C));
          C := 0;
          ProcessEntity;
          CONTINUE;
        end;
      #0:
        begin
          if EntityStack.Count = 0 then
            Break
          else
          begin
            CurContent := CurContent + TranslateEncoding(StrLPas(CurFinal - C, C));
            C := 0;
            CurFinal := EntityStack.Pop;
            CONTINUE;
          end;
        end;
      '<':
        Break;
    else
      INC(C);
    end;
    INC(CurFinal);
  until FALSE;
  CurContent := CurContent + TranslateEncoding(StrLPas(CurFinal - C, C));
  DEC(CurFinal);

  if FNormalize then
  begin
    CurContent := ConvertWs(TrimWs(CurContent), TRUE);
    IsDone := CurContent <> ''; // IsDone will only get FALSE if PackSpaces is TRUE
  end;
end;

procedure TXmlParser.AnalyzeElementDecl(Start: PWideChar; var Final: PWideChar);
(* Parse <!ELEMENT declaration starting at "Start"
  Final must point to the terminating '>' character
  XmlSpec 3.2:
  elementdecl ::= '<!ELEMENT' S Name S contentspec S? '>'
  contentspec ::= 'EMPTY' | 'ANY' | Mixed | children
  Mixed       ::= '(' S? '#PCDATA' (S? '|' S? Name)* S? ')*'   |
  '(' S? '#PCDATA' S? ')'
  children    ::= (choice | seq) ('?' | '*' | '+')?
  choice      ::= '(' S? cp ( S? '|' S? cp )* S? ')'
  cp          ::= (Name | choice | seq) ('?' | '*' | '+')?
  seq         ::= '(' S? cp ( S? ',' S? cp )* S? ')'

  More simply:
  contentspec ::= EMPTY
  ANY
  '(#PCDATA)'
  '(#PCDATA | A | B)*'
  '(A, B, C)'
  '(A | B | C)'
  '(A?, B*, C+),
  '(A, (B | C | D)* )' *)
var
  Element: TElemDef;
  Elem2: TElemDef;
  f: PWideChar;
  DER: TDtdElementRec;
begin
  Element := TElemDef.Create;
  final := Start + 9;
  DER.Start := Start;
  repeat
    if final^ = '>' then
      Break;
    if CharInSet(final^, CNameStart) and (Element.Name = '') then
    begin
      ExtractName(final, CWhitespace, f);
      SetStringSF(Element.Name, final, f);
      final := f;
      f := StrScan(final + 1, '>');
      if f = nil then
      begin
        Element.Definition := string(final);
        final := StrEnd(final);
        Break;
      end
      else
      begin
        SetStringSF(Element.Definition, final + 1, f - 1);
        final := f;
        Break;
      end;
    end;
    INC(final);
  until FALSE;
  Element.Definition := DelChars(Element.Definition, CWhitespace);
  ReplaceParameterEntities(Element.Definition);
  if Element.Definition = 'EMPTY' then
    Element.ElemType := etEmpty
  else if Element.Definition = 'ANY' then
    Element.ElemType := etAny
  else if Copy(Element.Definition, 1, 8) = '(#PCDATA' then
    Element.ElemType := etMixed
  else if Copy(Element.Definition, 1, 1) = '(' then
    Element.ElemType := etChildren
  else
    Element.ElemType := etAny;

  Elem2 := Elements.Node(Element.Name);
  if Elem2 <> nil then
    Elements.Delete(Elements.IndexOf(Elem2));
  Elements.Add(Element);
  final := StrScanE(final, '>');
  DER.ElementType := deElement;
  DER.ElemDef := Element;
  DER.Final := final;
  DtdElementFound(DER);
end;

procedure TXmlParser.AnalyzeAttListDecl(Start: PWideChar; var Final: PWideChar);
(* Parse <!ATTLIST declaration starting at "Start"
  Final must point to the terminating '>' character
  XmlSpec 3.3:
  AttlistDecl    ::= '<!ATTLIST' S Name AttDef* S? '>'
  AttDef         ::= S Name S AttType S DefaultDecl
  AttType        ::= StringType | TokenizedType | EnumeratedType
  StringType     ::= 'CDATA'
  TokenizedType  ::= 'ID' | 'IDREF' | 'IDREFS' | 'ENTITY' | 'ENTITIES' | 'NMTOKEN' | 'NMTOKENS'
  EnumeratedType ::= NotationType | Enumeration
  NotationType   ::= 'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')'
  Enumeration    ::= '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'
  DefaultDecl    ::= '#REQUIRED' | '#IMPLIED' | (('#FIXED' S)? AttValue)
  AttValue       ::= '"' ([^<&"] | Reference)* '"' | "'" ([^<&'] | Reference)* "'"
  Examples:
  <!ATTLIST address
  A1 CDATA "Default"
  A2 ID    #REQUIRED
  A3 IDREF #IMPLIED
  A4 IDREFS #IMPLIED
  A5 ENTITY #FIXED "&at;&#252;"
  A6 ENTITIES #REQUIRED
  A7 NOTATION (WMF | DXF) "WMF"
  A8 (A | B | C) #REQUIRED> *)
type
  TPhase = (phElementName, phName, phType, phNotationContent, phDefault);
var
  Phase: TPhase;
  f: PWideChar;
  ElementName: string;
  ElemDef: TElemDef;
  AttrDef: TAttrDef;
  AttrDef2: TAttrDef;
  Strg: string;
  DER: TDtdElementRec;
begin
  final := Start + 9; // The character after <!ATTLIST
  Phase := phElementName;
  DER.Start := Start;
  AttrDef := nil;
  ElemDef := nil;
  repeat
    if not CharInSet(final^, CWhitespace) then
      case final^ of
        '%':
          begin
            PushPE(final);
            CONTINUE;
          end;
        #0:
          if EntityStack.Count = 0 then
            Break
          else
          begin
            final := EntityStack.Pop;
            CONTINUE;
          end;
        '>':
          Break;
      else
        case Phase of
          phElementName:
            begin
              ExtractName(final, CWhitespace + CQuoteChar + ['#'], f);
              SetStringSF(ElementName, final, f);
              final := f;
              ElemDef := Elements.Node(ElementName);
              if ElemDef = nil then
              begin
                ElemDef := TElemDef.Create;
                ElemDef.Name := ElementName;
                ElemDef.Definition := 'ANY';
                ElemDef.ElemType := etAny;
                Elements.Add(ElemDef);
              end;
              Phase := phName;
            end;
          phName:
            begin
              AttrDef := TAttrDef.Create;
              ExtractName(final, CWhitespace + CQuoteChar + ['#'], f);
              SetStringSF(AttrDef.Name, final, f);
              final := f;
              AttrDef2 := TAttrDef(ElemDef.Node(AttrDef.Name));
              if AttrDef2 <> nil then
                ElemDef.Delete(ElemDef.IndexOf(AttrDef2));
              ElemDef.Add(AttrDef);
              Phase := phType;
            end;
          phType:
            begin
              if final^ = '(' then
              begin
                f := StrScan(final + 1, ')');
                if f <> nil then
                  SetStringSF(AttrDef.TypeDef, final + 1, f - 1)
                else
                  AttrDef.TypeDef := string(final + 1);
                AttrDef.TypeDef := DelChars(AttrDef.TypeDef, CWhitespace);
                AttrDef.AttrType := atEnumeration;
                ReplaceParameterEntities(AttrDef.TypeDef);
                ReplaceCharacterEntities(AttrDef.TypeDef);
                Phase := phDefault;
              end
              else if StrLComp(final, 'NOTATION', 8) = 0 then
              begin
                INC(final, 8);
                AttrDef.AttrType := atNotation;
                Phase := phNotationContent;
              end
              else
              begin
                ExtractName(final, CWhitespace + CQuoteChar + ['#'], f);
                SetStringSF(AttrDef.TypeDef, final, f);
                if AttrDef.TypeDef = 'CDATA' then
                  AttrDef.AttrType := atCData
                else if AttrDef.TypeDef = 'ID' then
                  AttrDef.AttrType := atID
                else if AttrDef.TypeDef = 'IDREF' then
                  AttrDef.AttrType := atIdRef
                else if AttrDef.TypeDef = 'IDREFS' then
                  AttrDef.AttrType := atIdRefs
                else if AttrDef.TypeDef = 'ENTITY' then
                  AttrDef.AttrType := atEntity
                else if AttrDef.TypeDef = 'ENTITIES' then
                  AttrDef.AttrType := atEntities
                else if AttrDef.TypeDef = 'NMTOKEN' then
                  AttrDef.AttrType := atNmToken
                else if AttrDef.TypeDef = 'NMTOKENS' then
                  AttrDef.AttrType := atNmTokens;
                Phase := phDefault;
              end
            end;
          phNotationContent:
            begin
              f := StrScan(final, ')');
              if f <> nil then
                SetStringSF(AttrDef.Notations, final + 1, f - 1)
              else
              begin
                AttrDef.Notations := string(final + 1);
                final := StrEnd(final);
              end;
              ReplaceParameterEntities(AttrDef.Notations);
              AttrDef.Notations := DelChars(AttrDef.Notations, CWhitespace);
              Phase := phDefault;
            end;
          phDefault:
            begin
              if final^ = '#' then
              begin
                ExtractName(final, CWhitespace + CQuoteChar, f);
                SetStringSF(Strg, final, f);
                final := f;
                ReplaceParameterEntities(Strg);
                if Strg = '#REQUIRED' then
                begin
                  AttrDef.DefaultType := adRequired;
                  Phase := phName;
                end
                else if Strg = '#IMPLIED' then
                begin
                  AttrDef.DefaultType := adImplied;
                  Phase := phName;
                end
                else if Strg = '#FIXED' then
                  AttrDef.DefaultType := adFixed;
              end
              else if CharInSet(final^, CQuoteChar) then
              begin
                ExtractQuote(final, AttrDef.Value, final);
                ReplaceParameterEntities(AttrDef.Value);
                ReplaceCharacterEntities(AttrDef.Value);
                Phase := phName;
              end;
              if Phase = phName then
              begin
                AttrDef := nil;
              end;
            end;

        end;
      end;
    INC(final);
  until FALSE;

  final := StrScan(final, '>');

  DER.ElementType := deAttList;
  DER.ElemDef := ElemDef;
  DER.Final := final;
  DtdElementFound(DER);
end;

procedure TXmlParser.AnalyzeEntityDecl(Start: PWideChar; var Final: PWideChar);
(* Parse <!ENTITY declaration starting at "Start"
  Final must point to the terminating '>' character
  XmlSpec 4.2:
  EntityDecl  ::= '<!ENTITY' S Name S EntityDef S? '>'   |
  '<!ENTITY' S '%' S Name S PEDef S? '>'
  EntityDef   ::= EntityValue | (ExternalID NDataDecl?)
  PEDef       ::= EntityValue | ExternalID
  NDataDecl   ::= S 'NDATA' S Name
  EntityValue ::= '"' ([^%&"] | PEReference | EntityRef | CharRef)* '"'   |
  "'" ([^%&'] | PEReference | EntityRef | CharRef)* "'"
  PEReference ::= '%' Name ';'

  Examples
  <!ENTITY test1 "Stefan Heymann">                   <!-- Internal, general, parsed              -->
  <!ENTITY test2 SYSTEM "ent2.xml">                  <!-- External, general, parsed              -->
  <!ENTITY test2 SYSTEM "ent3.gif" NDATA gif>        <!-- External, general, unparsed            -->
  <!ENTITY % test3 "<!ELEMENT q ANY>">               <!-- Internal, parameter                    -->
  <!ENTITY % test6 SYSTEM "ent6.xml">                <!-- External, parameter                    -->
  <!ENTITY test4 "&test1; ist lieb">                 <!-- IGP, Replacement text <> literal value -->
  <!ENTITY test5 "<p>Dies ist ein Test-Absatz</p>">  <!-- IGP, See XmlSpec 2.4                   -->
*)
type
  TPhase = (phName, phContent, phNData, phNotationName, phFinalGT);
var
  Phase: TPhase;
  IsParamEntity: BOOLEAN;
  f: PWideChar;
  ExternalID: TExternalID;
  EntityDef: TEntityDef;
  EntityDef2: TEntityDef;
  DER: TDtdElementRec;
begin
  final := Start + 8; // First char after <!ENTITY
  DER.Start := Start;
  Phase := phName;
  IsParamEntity := FALSE;
  EntityDef := TEntityDef.Create;
  repeat
    if not CharInSet(final^, CWhitespace) then
      case final^ of
        '%':
          IsParamEntity := TRUE;
        '>':
          Break;
      else
        case Phase of
          phName:
            if CharInSet(final^, CNameStart) then
            begin
              ExtractName(final, CWhitespace + CQuoteChar, f);
              SetStringSF(EntityDef.Name, final, f);
              final := f;
              Phase := phContent;
            end;
          phContent:
            if CharInSet(final^, CQuoteChar) then
            begin
              ExtractQuote(final, EntityDef.Value, final);
              Phase := phFinalGT;
            end
            else if (StrLComp(final, 'SYSTEM', 6) = 0) or (StrLComp(final, 'PUBLIC', 6) = 0) then
            begin
              ExternalID := TExternalID.Create(final);
              EntityDef.SystemId := ExternalID.SystemId;
              EntityDef.PublicId := ExternalID.PublicId;
              final := ExternalID.Final;
              Phase := phNData;
              ExternalID.Free;
            end;
          phNData:
            if StrLComp(final, 'NDATA', 5) = 0 then
            begin
              INC(final, 4);
              Phase := phNotationName;
            end;
          phNotationName:
            if CharInSet(final^, CNameStart) then
            begin
              ExtractName(final, CWhitespace + ['>'], f);
              SetStringSF(EntityDef.NotationName, final, f);
              final := f;
              Phase := phFinalGT;
            end;
          phFinalGT:
            ; // -!- There is an error in the document if this branch is called
        end;
      end;
    INC(final);
  until FALSE;
  if IsParamEntity then
  begin
    EntityDef2 := TEntityDef(ParEntities.Node(EntityDef.Name));
    if EntityDef2 <> nil then
      ParEntities.Delete(ParEntities.IndexOf(EntityDef2));
    ParEntities.Add(EntityDef);
    ReplaceCharacterEntities(EntityDef.Value);
  end
  else
  begin
    EntityDef2 := TEntityDef(Entities.Node(EntityDef.Name));
    if EntityDef2 <> nil then
      Entities.Delete(Entities.IndexOf(EntityDef2));
    Entities.Add(EntityDef);
    ReplaceParameterEntities(EntityDef.Value); // Create replacement texts (see XmlSpec 4.5)
    ReplaceCharacterEntities(EntityDef.Value);
  end;
  final := StrScanE(final, '>');

  DER.ElementType := deEntity;
  DER.EntityDef := EntityDef;
  DER.Final := final;
  DtdElementFound(DER);
end;

procedure TXmlParser.AnalyzeNotationDecl(Start: PWideChar; var Final: PWideChar);
// Parse <!NOTATION declaration starting at "Start"
// Final must point to the terminating '>' character
// XmlSpec 4.7: NotationDecl ::=  '<!NOTATION' S Name S (ExternalID |  PublicID) S? '>'
type
  TPhase = (phName, phExtId, phEnd);
var
  ExternalID: TExternalID;
  Phase: TPhase;
  f: PWideChar;
  NotationDef: TNotationDef;
  DER: TDtdElementRec;
begin
  final := Start + 10; // Character after <!NOTATION
  DER.Start := Start;
  Phase := phName;
  NotationDef := TNotationDef.Create;
  repeat
    if not CharInSet(final^, CWhitespace) then
      case final^ of
        '>', #0:
          Break;
      else
        case Phase of
          phName:
            begin
              ExtractName(final, CWhitespace + ['>'], f);
              SetStringSF(NotationDef.Name, final, f);
              final := f;
              Phase := phExtId;
            end;
          phExtId:
            begin
              ExternalID := TExternalID.Create(final);
              NotationDef.Value := ExternalID.SystemId;
              NotationDef.PublicId := ExternalID.PublicId;
              final := ExternalID.Final;
              ExternalID.Free;
              Phase := phEnd;
            end;
          phEnd:
            ; // -!- There is an error in the document if this branch is called
        end;
      end;
    INC(final);
  until FALSE;
  Notations.Add(NotationDef);
  final := StrScanE(final, '>');

  DER.ElementType := deNotation;
  DER.NotationDef := NotationDef;
  DER.Final := final;
  DtdElementFound(DER);
end;

procedure TXmlParser.PushPE(var Start: PWideChar);
(* If there is a parameter entity reference found in the data stream,
  the current position will be pushed to the entity stack.
  Start:  IN  Pointer to the '%' character starting the PE reference
  OUT Pointer to first character of PE replacement text *)
var
  P: PWideChar;
  EntityDef: TEntityDef;
begin
  P := StrScan(Start, ';');
  if P <> nil then
  begin
    EntityDef := TEntityDef(ParEntities.Node(StrSFPas(Start + 1, P - 1)));
    if EntityDef <> nil then
    begin
      EntityStack.Push(P + 1);
      Start := PWideChar(EntityDef.Value);
    end
    else
      Start := P + 1;
  end;
end;

procedure TXmlParser.ReplaceCharacterEntities(var Str: string);
// Replaces all Character Entity References in the String
var
  Start: INTEGER;
  PAmp: PWideChar;
  PSemi: PWideChar;
  PosAmp: INTEGER;
  Len: INTEGER; // Length of Entity Reference
begin
  if Str = '' then
    EXIT;
  Start := 1;
  repeat
    PAmp := StrPos(PWideChar(Str) + Start - 1, '&#');
    if PAmp = nil then
      Break;
    PSemi := StrScan(PAmp + 2, ';');
    if PSemi = nil then
      Break;
    PosAmp := PAmp - PWideChar(Str) + 1;
    Len := PSemi - PAmp + 1;
    if CompareText(Str[PosAmp + 2], 'x') = 0 // !!! Can't use "CHR" for Unicode characters > 255
    then
      Str[PosAmp] := CHR(StrToIntDef('$' + Copy(Str, PosAmp + 3, Len - 4), 0))
    else
      Str[PosAmp] := CHR(StrToIntDef(Copy(Str, PosAmp + 2, Len - 3), 32));
    Delete(Str, PosAmp + 1, Len - 1);
    Start := PosAmp + 1;
  until FALSE;
end;

procedure TXmlParser.ReplaceParameterEntities(var Str: string);
// Recursively replaces all Parameter Entity References in the String
  procedure ReplaceEntities(var Str: string);
  var
    Start: INTEGER;
    PAmp: PWideChar;
    PSemi: PWideChar;
    PosAmp: INTEGER;
    Len: INTEGER;
    Entity: TEntityDef;
    Repl: string; // Replacement
  begin
    if Str = '' then
      EXIT;
    Start := 1;
    repeat
      PAmp := StrPos(PWideChar(Str) + Start - 1, '%');
      if PAmp = nil then
        Break;
      PSemi := StrScan(PAmp + 2, ';');
      if PSemi = nil then
        Break;
      PosAmp := PAmp - PWideChar(Str) + 1;
      Len := PSemi - PAmp + 1;
      Entity := TEntityDef(ParEntities.Node(Copy(Str, PosAmp + 1, Len - 2)));
      if Entity <> nil then
      begin
        Repl := Entity.Value;
        ReplaceEntities(Repl); // Recursion
      end
      else
        Repl := Copy(Str, PosAmp, Len);
      Delete(Str, PosAmp, Len);
      Insert(Repl, Str, PosAmp);
      Start := PosAmp + Length(Repl);
    until FALSE;
  end;

begin
  ReplaceEntities(Str);
end;

procedure TXmlParser.ReplaceGeneralEntities(var Str: string);
// Recursively replaces General Entity References in the String
  procedure ReplaceEntities(var Str: string);
  var
    Start: INTEGER;
    PAmp: PWideChar;
    PSemi: PWideChar;
    PosAmp: INTEGER;
    Len: INTEGER;
    EntityDef: TEntityDef;
    EntName: string;
    Repl: string; // Replacement
    ExternalEntity: TXmlParser;
  begin
    if Str = '' then
      EXIT;
    Start := 1;
    repeat
      PAmp := StrPos(PWideChar(Str) + Start - 1, '&');
      if PAmp = nil then
        Break;
      PSemi := StrScan(PAmp + 2, ';');
      if PSemi = nil then
        Break;
      PosAmp := PAmp - PWideChar(Str) + 1;
      Len := PSemi - PAmp + 1;
      EntName := Copy(Str, PosAmp + 1, Len - 2);
      if EntName = 'lt' then
        Repl := '<'
      else if EntName = 'gt' then
        Repl := '>'
      else if EntName = 'amp' then
        Repl := '&'
      else if EntName = 'apos' then
        Repl := ''''
      else if EntName = 'quot' then
        Repl := '"'
      else
      begin
        EntityDef := TEntityDef(Entities.Node(EntName));
        if EntityDef <> nil then
        begin
          if EntityDef.Value <> '' then // Internal Entity
            Repl := EntityDef.Value
          else
          begin // External Entity
            ExternalEntity := LoadExternalEntity(EntityDef.SystemId, EntityDef.PublicId, EntityDef.NotationName);
            Repl := StrPas(ExternalEntity.DocBuffer); // !!! What if it contains a Text Declaration?
            ExternalEntity.Free;
          end;
          ReplaceEntities(Repl); // Recursion
        end
        else
          Repl := Copy(Str, PosAmp, Len);
      end;
      Delete(Str, PosAmp, Len);
      Insert(Repl, Str, PosAmp);
      Start := PosAmp + Length(Repl);
    until FALSE;
  end;

begin
  ReplaceEntities(Str);
end;

function TXmlParser.LoadExternalEntity(SystemId, PublicId, Notation: string): TXmlParser;
// This will be called whenever there is a Parsed External Entity or
// the DTD External Subset to be parsed.
// It has to create a TXmlParser instance and load the desired Entity.
// This instance of LoadExternalEntity assumes that "SystemId" is a valid
// file name (relative to the Document source) and loads this file using
// the LoadFromFile method.
var
  Filename: string;
begin
  // --- Convert System ID to complete filename
  Filename := StringReplace(SystemId, '/', '\', [rfReplaceAll]);
  if Copy(FSource, 1, 1) <> '<' then
    if (Copy(Filename, 1, 2) = '\\') or (Copy(Filename, 2, 1) = ':') then
      // Already has an absolute Path
    else
    begin
      Filename := ExtractFilePath(FSource) + Filename;
    end;

  // --- Load the File
  Result := TXmlParser.Create;
  Result.LoadFromFile(Filename);
end;

function TXmlParser.TranslateEncoding(const Source: string): string;
// The member variable "CurEncoding" always holds the name of the current
// encoding, e.g. 'UTF-8' or 'ISO-8859-1'.
// This virtual method "TranslateEncoding" is responsible for translating
// the content passed in the "Source" parameter to the Encoding which
// is expected by the application.
// This instance of "TranlateEncoding" assumes that the Application expects
// Windows ANSI (Win1252) strings. It is able to transform UTF-8 or ISO-8859-1
// encodings.
// If you want your application to understand or create other encodings, you
// override this function.
begin
  if CurEncoding = 'UTF-8' then
    Result := string(Utf8ToAnsi(Source))
  else
    Result := Source;
end;

procedure TXmlParser.DtdElementFound(DtdElementRec: TDtdElementRec);
// This method is called for every element which is found in the DTD
// declaration. The variant record TDtdElementRec is passed which
// holds informations about the element.
// You can override this function to handle DTD declarations.
// Note that when you parse the same Document instance a second time,
// the DTD will not get parsed again.
begin
end;

function TXmlParser.GetDocBuffer: PWideChar;
// Returns FBuffer or a pointer to a NUL char if Buffer is empty
begin
  if FBuffer = nil then
    Result := #0
  else
    Result := FBuffer;
end;

(*$IFNDEF HAS_CONTNRS_UNIT
===============================================================================================
TObjectList
===============================================================================================
*)

destructor TObjectList.Destroy;
begin
  Clear;
  SetCapacity(0);
  inherited Destroy;
end;

procedure TObjectList.Delete(Index: INTEGER);
begin
  if (index < 0) or (index >= Count) then
    EXIT;
  TObject(Items[index]).Free;
  inherited Delete(index);
end;

procedure TObjectList.Clear;
begin
  while Count > 0 do
    Delete(Count - 1);
end;

(*$ENDIF *)
(*
  ===============================================================================================
  TNvpNode
  --------
  Node base class for the TNvpList
  ===============================================================================================
*)

constructor TNvpNode.Create(TheName, TheValue: string);
begin
  inherited Create;
  name := TheName;
  Value := TheValue;
end;

(*
  ===============================================================================================
  TNvpList
  --------
  A generic List of Name-Value Pairs, based on the TObjectList introduced in Delphi 5
  ===============================================================================================
*)

procedure TNvpList.Add(Node: TNvpNode);
var
  I: INTEGER;
begin
  for I := Count - 1 downto 0 do
    if Node.Name > TNvpNode(Items[I]).Name then
    begin
      Insert(I + 1, Node);
      EXIT;
    end;
  Insert(0, Node);
end;

function TNvpList.Node(Name: string): TNvpNode;
// Binary search for Node
var
  L, H: INTEGER; // Low, High Limit
  T, C: INTEGER; // Test Index, Comparison result
  Last: INTEGER; // Last Test Index
begin
  if Count = 0 then
  begin
    Result := nil;
    EXIT;
  end;

  L := 0;
  H := Count;
  Last := -1;
  repeat
    T := (L + H) div 2;
    if T = Last then
      Break;
    Result := TNvpNode(Items[T]);
    C := CompareStr(Result.Name, name);
    if C = 0 then
      EXIT
    else if C < 0 then
      L := T
    else
      H := T;
    Last := T;
  until FALSE;
  Result := nil;
end;

function TNvpList.Node(Index: INTEGER): TNvpNode;
begin
  if (index < 0) or (index >= Count) then
    Result := nil
  else
    Result := TNvpNode(Items[index]);
end;

function TNvpList.Value(Name: string): string;
var
  Nvp: TNvpNode;
begin
  Nvp := TNvpNode(Node(name));
  if Nvp <> nil then
    Result := Nvp.Value
  else
    Result := '';
end;

function TNvpList.Value(Index: INTEGER): string;
begin
  if (index < 0) or (index >= Count) then
    Result := ''
  else
    Result := TNvpNode(Items[index]).Value;
end;

function TNvpList.Name(Index: INTEGER): string;
begin
  if (index < 0) or (index >= Count) then
    Result := ''
  else
    Result := TNvpNode(Items[index]).Name;
end;

(*
  ===============================================================================================
  TAttrList
  List of Attributes. The "Analyze" method extracts the Attributes from the given Buffer.
  Is used for extraction of Attributes in Start-Tags, Empty-Element Tags and the "pseudo"
  attributes in XML Prologs, Text Declarations and PIs.
  ===============================================================================================
*)

procedure TAttrList.Analyze(Start: PWideChar; var Final: PWideChar);
// Analyze the Buffer for Attribute=Name pairs.
// Terminates when there is a character which is not IN CNameStart
// (e.g. '?>' or '>' or '/>')
type
  TPhase = (phName, phEq, phValue);
var
  Phase: TPhase;
  f: PWideChar;
  Name: string;
  Value: string;
  Attr: TAttr;
begin
  Clear;
  Phase := phName;
  final := Start;
  repeat
    if (final^ = #0) or (final^ = '>') then
      Break;
    if not CharInSet(final^, CWhitespace) then
      case Phase of
        phName:
          begin
            if not CharInSet(final^, CNameStart) then
              EXIT;
            ExtractName(final, CWhitespace + ['=', '/'], f);
            SetStringSF(name, final, f);
            final := f;
            Phase := phEq;
          end;
        phEq:
          begin
            if final^ = '=' then
              Phase := phValue
          end;
        phValue:
          begin
            if CharInSet(final^, CQuoteChar) then
            begin
              ExtractQuote(final, Value, f);
              Attr := TAttr.Create;
              Attr.Name := name;
              Attr.Value := Value;
              Attr.ValueType := vtNormal;
              Add(Attr);
              final := f;
              Phase := phName;
            end;
          end;
      end;
    INC(final);
  until FALSE;
end;

(*
  ===============================================================================================
  TElemList
  List of TElemDef nodes.
  ===============================================================================================
*)

function TElemList.Node(Name: string): TElemDef;
// Binary search for the Node with the given Name
var
  L, H: INTEGER; // Low, High Limit
  T, C: INTEGER; // Test Index, Comparison result
  Last: INTEGER; // Last Test Index
begin
  if Count = 0 then
  begin
    Result := nil;
    EXIT;
  end;

  L := 0;
  H := Count;
  Last := -1;
  repeat
    T := (L + H) div 2;
    if T = Last then
      Break;
    Result := TElemDef(Items[T]);
    C := CompareStr(Result.Name, name);
    if C = 0 then
      EXIT
    else if C < 0 then
      L := T
    else
      H := T;
    Last := T;
  until FALSE;
  Result := nil;
end;

procedure TElemList.Add(Node: TElemDef);
var
  I: INTEGER;
begin
  for I := Count - 1 downto 0 do
    if Node.Name > TElemDef(Items[I]).Name then
    begin
      Insert(I + 1, Node);
      EXIT;
    end;
  Insert(0, Node);
end;

(*
  ===============================================================================================
  TScannerXmlParser
  A TXmlParser descendant for the TCustomXmlScanner component
  ===============================================================================================
*)

type
  TScannerXmlParser = class(TXmlParser)
    Scanner: TCustomXmlScanner;
    constructor Create(TheScanner: TCustomXmlScanner);
    function LoadExternalEntity(SystemId, PublicId, Notation: string): TXmlParser; override;
    function TranslateEncoding(const Source: string): string; override;
    procedure DtdElementFound(DtdElementRec: TDtdElementRec); override;
  end;

constructor TScannerXmlParser.Create(TheScanner: TCustomXmlScanner);
begin
  inherited Create;
  Scanner := TheScanner;
end;

function TScannerXmlParser.LoadExternalEntity(SystemId, PublicId, Notation: string): TXmlParser;
begin
  if Assigned(Scanner.FOnLoadExternal) then
    Scanner.FOnLoadExternal(Scanner, SystemId, PublicId, Notation, Result)
  else
    Result := inherited LoadExternalEntity(SystemId, PublicId, Notation);
end;

function TScannerXmlParser.TranslateEncoding(const Source: string): string;
begin
  if Assigned(Scanner.FOnTranslateEncoding) then
    Result := Scanner.FOnTranslateEncoding(Scanner, CurEncoding, Source)
  else
    Result := inherited TranslateEncoding(Source);
end;

procedure TScannerXmlParser.DtdElementFound(DtdElementRec: TDtdElementRec);
begin
  with DtdElementRec do
    case ElementType of
      deElement:
        Scanner.WhenElement(ElemDef);
      deAttList:
        Scanner.WhenAttList(ElemDef);
      deEntity:
        Scanner.WhenEntity(EntityDef);
      deNotation:
        Scanner.WhenNotation(NotationDef);
      dePI:
        Scanner.WhenPI(string(Target), string(Content), AttrList);
      deComment:
        Scanner.WhenComment(StrSFPas(Start, final));
      deError:
        Scanner.WhenDtdError(Pos);
    end;
end;

(*
  ===============================================================================================
  TCustomXmlScanner
  ===============================================================================================
*)

constructor TCustomXmlScanner.Create(AOwner: TComponent);
begin
  inherited;
  FXmlParser := TScannerXmlParser.Create(Self);
end;

destructor TCustomXmlScanner.Destroy;
begin
  FXmlParser.Free;
  inherited;
end;

procedure TCustomXmlScanner.LoadFromFile(Filename: TFilename);
// Load XML Document from file
begin
  FXmlParser.LoadFromFile(Filename);
end;

procedure TCustomXmlScanner.LoadFromBuffer(Buffer: PWideChar);
// Load XML Document from buffer
begin
  FXmlParser.LoadFromBuffer(Buffer);
end;

procedure TCustomXmlScanner.SetBuffer(Buffer: PWideChar);
// Refer to Buffer
begin
  FXmlParser.SetBuffer(Buffer);
end;

function TCustomXmlScanner.GetFilename: TFilename;
begin
  Result := FXmlParser.Source;
end;

function TCustomXmlScanner.GetNormalize: BOOLEAN;
begin
  Result := FXmlParser.Normalize;
end;

procedure TCustomXmlScanner.SetNormalize(Value: BOOLEAN);
begin
  FXmlParser.Normalize := Value;
end;

procedure TCustomXmlScanner.WhenXmlProlog(XmlVersion, Encoding: string; Standalone: BOOLEAN);
// Is called when the parser has parsed the <? xml ?> declaration of the prolog
begin
  if Assigned(FOnXmlProlog) then
    FOnXmlProlog(Self, XmlVersion, Encoding, Standalone);
end;

procedure TCustomXmlScanner.WhenComment(Comment: string);
// Is called when the parser has parsed a <!-- comment -->
begin
  if Assigned(FOnComment) then
    FOnComment(Self, Comment);
end;

procedure TCustomXmlScanner.WhenPI(Target, Content: string; Attributes: TAttrList);
// Is called when the parser has parsed a <?processing instruction ?>
begin
  if Assigned(FOnPI) then
    FOnPI(Self, Target, Content, Attributes);
end;

procedure TCustomXmlScanner.WhenDtdRead(RootElementName: string);
// Is called when the parser has completely parsed the DTD
begin
  if Assigned(FOnDtdRead) then
    FOnDtdRead(Self, RootElementName);
end;

procedure TCustomXmlScanner.WhenStartTag(TagName: string; Attributes: TAttrList);
// Is called when the parser has parsed a start tag like <p>
begin
  if Assigned(FOnStartTag) then
    FOnStartTag(Self, TagName, Attributes);
end;

procedure TCustomXmlScanner.WhenEmptyTag(TagName: string; Attributes: TAttrList);
// Is called when the parser has parsed an Empty Element Tag like <br/>
begin
  if Assigned(FOnEmptyTag) then
    FOnEmptyTag(Self, TagName, Attributes);
end;

procedure TCustomXmlScanner.WhenEndTag(TagName: string);
// Is called when the parser has parsed an End Tag like </p>
begin
  if Assigned(FOnEndTag) then
    FOnEndTag(Self, TagName);
end;

procedure TCustomXmlScanner.WhenContent(Content: string);
// Is called when the parser has parsed an element's text content
begin
  if Assigned(FOnContent) then
    FOnContent(Self, Content);
end;

procedure TCustomXmlScanner.WhenCData(Content: string);
// Is called when the parser has parsed a CDATA section
begin
  if Assigned(FOnCData) then
    FOnCData(Self, Content);
end;

procedure TCustomXmlScanner.WhenElement(ElemDef: TElemDef);
// Is called when the parser has parsed an <!ELEMENT> definition
// inside the DTD
begin
  if Assigned(FOnElement) then
    FOnElement(Self, ElemDef);
end;

procedure TCustomXmlScanner.WhenAttList(ElemDef: TElemDef);
// Is called when the parser has parsed an <!ATTLIST> definition
// inside the DTD
begin
  if Assigned(FOnAttList) then
    FOnAttList(Self, ElemDef);
end;

procedure TCustomXmlScanner.WhenEntity(EntityDef: TEntityDef);
// Is called when the parser has parsed an <!ENTITY> definition
// inside the DTD
begin
  if Assigned(FOnEntity) then
    FOnEntity(Self, EntityDef);
end;

procedure TCustomXmlScanner.WhenNotation(NotationDef: TNotationDef);
// Is called when the parser has parsed a <!NOTATION> definition
// inside the DTD
begin
  if Assigned(FOnNotation) then
    FOnNotation(Self, NotationDef);
end;

procedure TCustomXmlScanner.WhenDtdError(ErrorPos: PWideChar);
// Is called when the parser has found an Error in the DTD
begin
  if Assigned(FOnDtdError) then
    FOnDtdError(Self, ErrorPos);
end;

procedure TCustomXmlScanner.Execute;
// Perform scanning
// Scanning is done synchronously, i.e. you can expect events to be triggered
// in the order of the XML data stream. Execute will finish when the whole XML
// document has been scanned or when the StopParser property has been set to TRUE.
begin
  FStopParser := FALSE;
  FXmlParser.StartScan;
  while FXmlParser.Scan and (not FStopParser) do
    case FXmlParser.CurPartType of
      ptNone:
        ;
      ptXmlProlog:
        WhenXmlProlog(FXmlParser.XmlVersion, FXmlParser.Encoding, FXmlParser.Standalone);
      ptComment:
        WhenComment(StrSFPas(FXmlParser.CurStart, FXmlParser.CurFinal));
      ptPI:
        WhenPI(FXmlParser.CurName, FXmlParser.CurContent, FXmlParser.CurAttr);
      ptDtdc:
        WhenDtdRead(FXmlParser.RootName);
      ptStartTag:
        WhenStartTag(FXmlParser.CurName, FXmlParser.CurAttr);
      ptEmptyTag:
        WhenEmptyTag(FXmlParser.CurName, FXmlParser.CurAttr);
      ptEndTag:
        WhenEndTag(FXmlParser.CurName);
      ptContent:
        WhenContent(FXmlParser.CurContent);
      ptCData:
        WhenCData(FXmlParser.CurContent);
    end;
end;

end.