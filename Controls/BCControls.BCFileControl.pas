unit BCControls.BCFileControl;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls, Winapi.Messages, System.Types,
  Winapi.Windows, VirtualTrees, Vcl.ImgList, BCControls.BCEdit;

type
  TBCFileTreeView = class;

  TDriveComboFile = class
    Drive: string;
    IconIndex: Integer;
    FileName: string;
  end;

  TBCCustomDriveComboBox = class(TCustomComboBox)
  private
    { Private declarations }
    FDrive: Char;
    FIconIndex: Integer;
    FFileTreeView: TBCFileTreeView;
    FSystemIconsImageList: TImageList;
    procedure SetFileTreeView(Value: TBCFileTreeView);
    procedure GetSystemIcons;
    procedure ResetItemHeight;
    function GetDrive: Char;
    procedure SetDrive(NewDrive: Char);
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    { Protected declarations }
    procedure CreateWnd; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure Click; override;
    procedure BuildList; virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Drive: Char read GetDrive write SetDrive;
    property FileTreeView: TBCFileTreeView read FFileTreeView write SetFileTreeView;
    property SystemIconsImageList: TImageList read FSystemIconsImageList;
    property IconIndex: Integer read FIconIndex;
  end;

  TBCDriveComboBox = class(TBCCustomDriveComboBox)
  published
    { Published declarations }
    property Align;
    property Anchors;
    property AutoComplete;
    property AutoDropDown;
    property Color;
    property Constraints;
    property FileTreeView;
    property DoubleBuffered;
    property DragMode;
    property DragCursor;
    property Drive;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange;
    property OnClick;
    property OnCloseUp;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDropDown;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnSelect;
    property OnStartDock;
    property OnStartDrag;
  end;

  TBCFileType = (ftNone, ftDirectory, ftFile);

  PBCFileTreeNodeRec = ^TBCFileTreeNodeRec;
  TBCFileTreeNodeRec = record
    FileType: TBCFileType;
    FullPath, Filename: UnicodeString;
    OpenIndex, CloseIndex: Integer;
  end;

  TBCFileTreeView = class(TVirtualDrawTree)
  private
    FDrive: Char;
    FShowHidden: Boolean;
    FShowSystem: Boolean;
    FShowArchive: Boolean;
    FRootDirectory: string;
    FDefaultDirectoryPath: string;
    FExcludeOtherBranches: Boolean;
    procedure DriveChange(NewDrive: Char);
    procedure SetDrive(Value: Char);
    function IncludeTrailingBackslash(Path: string): string;
    function GetCloseIcon(Path: string): Integer;
    function GetOpenIcon(Path: string): Integer;
    procedure BuildTree(RootDirectory: string; ExcludeOtherBranches: Boolean);
    function GetSelectedPath: string;
    function GetSelectedFile: string;
  protected
    function DeleteTreeNode(Node: PVirtualNode): Boolean;
    procedure DoInitNode(Parent, Node: PVirtualNode; var InitStates: TVirtualNodeInitStates); override;
    procedure DoFreeNode(Node: PVirtualNode); override;
    procedure DoPaintNode(var PaintInfo: TVTPaintInfo); override;
    function DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
      var Ghosted: Boolean; var Index: Integer): TCustomImageList; override;
    function DoCompare(Node1, Node2: PVirtualNode; Column: TColumnIndex): Integer; override;
    function DoGetNodeWidth(Node: PVirtualNode; Column: TColumnIndex; Canvas: TCanvas = nil): Integer; override;
    procedure DoInitChildren(Node: PVirtualNode; var ChildCount: Cardinal); override;
    function DoCreateEditor(Node: PVirtualNode; Column: TColumnIndex): IVTEditLink; override;
  public
  { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenPath(RootDirectory: string; DirectoryPath: string; ExcludeOtherBranches: Boolean);
    procedure RenameSelectedNode;
    procedure DeleteSelectedNode;
    property Drive: Char read FDrive write SetDrive;
    property ShowHiddenFiles: Boolean read FShowHidden write FShowHidden;
    property ShowSystemFiles: Boolean read FShowSystem write FShowSystem;
    property ShowArchiveFiles: Boolean read FShowArchive write FShowArchive;
    property ExcludeOtherBranches: Boolean read FExcludeOtherBranches;
    property SelectedPath: string read GetSelectedPath;
    property SelectedFile: string read GetSelectedFile;
    property RootDirectory: string read FRootDirectory;
  end;

  TEditLink = class(TInterfacedObject, IVTEditLink)
  private
    FEdit: TBCEdit;
    FTree: TBCFileTreeView; // A back reference to the tree calling.
    FNode: PVirtualNode; // The node being edited.
    FColumn: Integer; // The column of the node being edited.
  protected
    procedure EditKeyPress(Sender: TObject; var Key: Char);
  public
    destructor Destroy; override;
    function BeginEdit: Boolean; stdcall;
    function CancelEdit: Boolean; stdcall;
    function EndEdit: Boolean; stdcall;
    function GetBounds: TRect; stdcall;
    function PrepareEdit(Tree: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex): Boolean; stdcall;
    procedure ProcessMessage(var Message: TMessage); stdcall;
    procedure SetBounds(R: TRect); stdcall;
  end;

procedure Register;

implementation

uses
  Vcl.Forms, Winapi.ShellAPI, Winapi.ShlObj, Winapi.ActiveX, Vcl.Dialogs, Vcl.Themes, BCCommon.Language,
  BCControls.BCImageList, System.UITypes;

const
  FILE_ATTRIBUTES = FILE_ATTRIBUTE_READONLY or FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM or FILE_ATTRIBUTE_ARCHIVE or FILE_ATTRIBUTE_NORMAL or FILE_ATTRIBUTE_DIRECTORY;

procedure Register;
begin
  RegisterComponents('bonecode', [TBCDriveComboBox]);
  RegisterComponents('bonecode', [TBCFileTreeView]);
end;

function GetItemHeight(Font: TFont): Integer;
var
  DC: HDC;
  SaveFont: HFont;
  Metrics: TTextMetric;
begin
  DC := GetDC(0);
  SaveFont := SelectObject(DC, Font.Handle);
  GetTextMetrics(DC, Metrics);
  SelectObject(DC, SaveFont);
  ReleaseDC(0, DC);
  Result := Metrics.tmHeight;
end;

{ TBCCustomDriveComboBox }

constructor TBCCustomDriveComboBox.Create(AOwner: TComponent);
var
  Temp: string;
begin
  inherited Create(AOwner);
  Style := csOwnerDrawFixed;
  GetSystemIcons;
  GetDir(0, Temp);
  FDrive := Temp[1]; { make default drive selected }
  if FDrive = '\' then
    FDrive := #0;
end;

procedure TBCCustomDriveComboBox.CreateWnd;
begin
  inherited CreateWnd;
  BuildList;
  SetDrive(FDrive);
end;

destructor TBCCustomDriveComboBox.Destroy;
begin
  FreeAndNil(FSystemIconsImageList);
  inherited Destroy;
end;

function FileIconInit(FullInit: BOOL): BOOL; stdcall;
type
  TFileIconInit = function(FullInit: BOOL): BOOL; stdcall;
var
  ShellDLL: HMODULE;
  PFileIconInit: TFileIconInit;
begin
  Result := False;
  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
    ShellDLL := LoadLibrary(PChar('shell32.dll'));
    PFileIconInit := GetProcAddress(ShellDLL, PChar(660));
    if Assigned(PFileIconInit) then
      Result := PFileIconInit(FullInit);
  end;
end;

procedure TBCCustomDriveComboBox.GetSystemIcons;
var
  SHFileInfo: TSHFileInfo;
  PathInfo: string;
begin
  FileIconInit(True);
  FSystemIconsImageList := TImageList.Create(Self);
  //PathInfo := 'dummy';
  FSystemIconsImageList.Handle := SHGetFileInfo(PChar(PathInfo), 0, SHFileInfo, SizeOf(SHFileInfo), SHGFI_ICON or SHGFI_SYSICONINDEX or SHGFI_SMALLICON);
end;

procedure TBCCustomDriveComboBox.BuildList;
var
  Drives: set of 0..25;
  SHFileInfo: TSHFileInfo;
  lp1: Integer;
  Drv: string;
  DriveComboFile: TDriveComboFile;
begin
  Items.BeginUpdate;

  Items.Clear;
  Integer(Drives) := GetLogicalDrives;

  for lp1 := 0 to 25 do
  begin
    if (lp1 in Drives) then
    begin
      Drv := chr(ord('A') + lp1) + ':\';
      try
        SHGetFileInfo(PChar(Drv), 0, SHFileInfo, SizeOf(SHFileInfo), SHGFI_SYSICONINDEX or SHGFI_DISPLAYNAME or SHGFI_TYPENAME);
        DriveComboFile := TDriveComboFile.Create;
        DriveComboFile.Drive := chr(ord('A') + lp1);
        DriveComboFile.IconIndex := SHFileInfo.iIcon;
        DriveComboFile.FileName := StrPas(SHFileInfo.szDisplayName);
        Items.AddObject(StrPas(SHFileInfo.szDisplayName), DriveComboFile);
      except

      end;
    end;
  end;
  Items.EndUpdate;
end;

function TBCCustomDriveComboBox.GetDrive: Char;
begin
  Result := FDrive;
end;

procedure TBCCustomDriveComboBox.SetDrive(NewDrive: Char);
var
  Item: Integer;
begin
  if (ItemIndex < 0) or (UpCase(NewDrive) <> UpCase(FDrive)) then
  begin
    FDrive := NewDrive;
    if NewDrive = #0 then
      ItemIndex := -1
    else
    { change selected item }
    for Item := 0 to Items.Count - 1 do
      if UpCase(NewDrive) = TDriveComboFile(Items.Objects[Item]).Drive then
      begin
        ItemIndex := Item;
        break;
      end;
    FIconIndex := TDriveComboFile(Items.Objects[ItemIndex]).IconIndex;
    if Assigned(FFileTreeView) then
      FFileTreeView.DriveChange(NewDrive);
    Change;
  end;
end;

procedure TBCCustomDriveComboBox.SetFileTreeView(Value: TBCFileTreeView);
begin
  FFileTreeView := Value;
  if Assigned(FFileTreeView) then
  begin
    FFileTreeView.Drive := #0;
    FFileTreeView.DriveChange(Drive);
  end;
end;

procedure TBCCustomDriveComboBox.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  { ensure the correct highlite color is used }
  Canvas.FillRect(Rect);
  { draw the actual bitmap }
  FSystemIconsImageList.Draw(Canvas, Rect.Left + 3, Rect.Top, TDriveComboFile(Items.Objects[Index]).IconIndex);
  { write the text }
  Canvas.TextOut(Rect.Left + FSystemIconsImageList.width + 7, Rect.Top + 2,
    TDriveComboFile(Items.Objects[Index]).FileName);
end;

procedure TBCCustomDriveComboBox.Click;
begin
  inherited Click;
  if ItemIndex >= 0 then
    Drive := TDriveComboFile(Items.Objects[ItemIndex]).Drive[1];
end;

procedure TBCCustomDriveComboBox.CMFontChanged(var Message: TMessage);
begin
  inherited;
  ResetItemHeight;
  RecreateWnd;
end;

procedure TBCCustomDriveComboBox.ResetItemHeight;
var
  nuHeight: Integer;
begin
  nuHeight :=  GetItemHeight(Font);
  if nuHeight < FSystemIconsImageList.Height then
    nuHeight := FSystemIconsImageList.Height;
  ItemHeight := nuHeight;
end;

procedure TBCCustomDriveComboBox.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FFileTreeView) then
    FFileTreeView := nil;
end;

{ TBCFileTreeView }

constructor TBCFileTreeView.Create;
var
  SHFileInfo: TSHFileInfo;
  PathInfo: String;
  SysImageList: THandle;
begin
  inherited Create(AOwner);

  DragOperations := [];
  Header.Options := [];
  IncrementalSearch := isAll;
  Indent := 20; //16;
  EditDelay := 500;

  TreeOptions.AutoOptions := [toAutoDropExpand, toAutoScroll, toAutoChangeScale, toAutoScrollOnExpand, toAutoTristateTracking, toAutoDeleteMovedNodes];
  TreeOptions.MiscOptions := [toEditable, toFullRepaintOnResize, toInitOnSave, toToggleOnDblClick, toWheelPanning, toEditOnClick];
  TreeOptions.PaintOptions := [toShowBackground, toShowButtons, toShowDropmark, toShowRoot, toUseBlendedSelection, {toUseBlendedImages,} toThemeAware , toUseExplorerTheme];

  FShowHidden := False;
  FShowArchive := True;
  FShowSystem := False;

  FileIconInit(True);
  Images := TBCImageList.Create(Self);
  SysImageList := SHGetFileInfo(PChar(PathInfo), 0, SHFileInfo, SizeOf(SHFileInfo), SHGFI_SYSICONINDEX or SHGFI_SMALLICON);
  if SysImageList <> 0 then
  begin
    Images.Handle := SysImageList;
    Images.BkColor := ClNone;
    Images.ShareImages := True;
  end;

  FDrive := #0;
end;


destructor TBCFileTreeView.Destroy;
begin
  Images.Free;

  inherited Destroy;
end;

procedure TBCFileTreeView.DriveChange(NewDrive: Char);
begin
  if UpCase(NewDrive) <> UpCase(Drive) then
  begin
    FDrive := NewDrive;
    FRootDirectory := NewDrive + ':\';
    if not (csDesigning in ComponentState) then
      BuildTree(FRootDirectory, False);
  end
end;

procedure TBCFileTreeView.SetDrive(Value: Char);
begin
  if (UpCase(Value) <> UpCase(Drive)) then
  begin
    FDrive := Value;
    DriveChange(Value);
  end;
end;

function TBCFileTreeView.IncludeTrailingBackslash(Path: string): string;
begin
  if Path = '' then
    Exit;
  if not IsPathDelimiter(Path, Length(Path)) then
    Result := Path + '\'
  else
    Result := Path;
end;

function GetIconIndex(Path: string; Flags: Cardinal): Integer;
var
  SHFileInfo: TSHFileInfo;
begin
  if SHGetFileInfo(PChar(Path), 0, SHFileInfo, SizeOf(SHFileInfo), Flags) = 0 then
    Result := -1
  else
    Result := SHFileInfo.iIcon;
end;

function TBCFileTreeView.GetCloseIcon(Path: string): Integer;
begin
  Result := GetIconIndex(Path, SHGFI_SYSICONINDEX or SHGFI_SMALLICON);
end;

function TBCFileTreeView.GetOpenIcon(Path: string): Integer;
begin
  Result := GetIconIndex(Path, SHGFI_SYSICONINDEX or SHGFI_SMALLICON or SHGFI_OPENICON);
end;

procedure TBCFileTreeView.BuildTree(RootDirectory: string; ExcludeOtherBranches: Boolean);
var
  FindFile: Integer;
  ANode: PVirtualNode;
  SR: TSearchRec;
  FileName: string;
  Data: PBCFileTreeNodeRec;
begin
  BeginUpdate;
  Clear;
  NodeDataSize := SizeOf(TBCFileTreeNodeRec);

  if not ExcludeOtherBranches then
    FindFile := FindFirst(FDrive + ':\*.*', faAnyFile, SR)
  else
    FindFile := FindFirst(IncludeTrailingBackslash(RootDirectory) + '*.*', faAnyFile, SR);

  if FindFile = 0 then
  try
    Screen.Cursor := crHourGlass;
    repeat
      {$WARNINGS OFF}
      if ((SR.Attr and faHidden <> 0) and not ShowHiddenFiles) or
          ((SR.Attr and faArchive <> 0) and not ShowArchiveFiles) or
          ((SR.Attr and faSysFile <> 0) and not ShowSystemFiles) then
          Continue;
      {$WARNINGS ON}
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        ANode := AddChild(nil);
        //Include(ANode.States, vsInitialUserData);
        {
          There's a bug in VirtualTrees.pas, comment following lines:

          function TBaseVirtualTree.GetNodeData(Node: PVirtualNode): Pointer;
          ...
          //if ([vsInitialized, vsInitialUserData] * Node.States = []) then
          //  InitNode(Node);
          ...
        }
        Data := GetNodeData(ANode);
        if not ExcludeOtherBranches then
          FileName := FDrive + ':\' + SR.Name
        else
          FileName := IncludeTrailingBackslash(RootDirectory) + SR.Name;
        if (SR.Attr and faDirectory <> 0) then
        begin
          Data.FileType := ftDirectory;
          Data.FullPath := IncludeTrailingBackslash(FileName);
        end
        else
        begin
          Data.FileType := ftFile;
          if not ExcludeOtherBranches then
            Data.FullPath := FDrive + ':\'
          else
            Data.FullPath := IncludeTrailingBackslash(RootDirectory);
        end;
        Data.Filename := SR.Name;
        Data.CloseIndex := GetCloseIcon(Filename);
        Data.OpenIndex := GetOpenIcon(Filename);
      end;
    until FindNext(SR) <> 0;
  finally
    System.SysUtils.FindClose(SR);
    Screen.Cursor := crDefault;
  end;
  Sort(nil, 0, sdAscending, False);

  EndUpdate;
end;

function TBCFileTreeView.GetSelectedPath: string;
var
  TreeNode: PVirtualNode;
  Data: PBCFileTreeNodeRec;
begin
  Result := '';

  TreeNode := GetFirstSelected;
  if not Assigned(TreeNode) then
  begin
    if not FExcludeOtherBranches then
      Result := Drive + ':\'
    else
      Result := FDefaultDirectoryPath;
  end
  else
  begin
    Data := GetNodeData(TreeNode);
    Result := IncludeTrailingBackslash(Data.FullPath);
  end;
end;

function TBCFileTreeView.GetSelectedFile: string;
var
  TreeNode: PVirtualNode;
  Data: PBCFileTreeNodeRec;
begin
  Result := '';
  TreeNode := GetFirstSelected;
  if not Assigned(TreeNode) then
    Exit;
  if TreeNode.ChildCount > 0 then
    Exit;

  Data := GetNodeData(TreeNode);

  Result := IncludeTrailingBackslash(Data.FullPath);
  if System.SysUtils.FileExists(Result + Data.Filename) then
    Result := Result + Data.Filename;
end;

procedure TBCFileTreeView.OpenPath(RootDirectory: string; DirectoryPath: string; ExcludeOtherBranches: Boolean);
var
  CurNode: PVirtualNode;
  Data: PBCFileTreeNodeRec;
  TempPath, Directory: string;
begin
  if not DirectoryExists(RootDirectory) then
    Exit;
  if not DirectoryExists(DirectoryPath) then
    Exit;
  BeginUpdate;
  FDefaultDirectoryPath := DirectoryPath;
  FExcludeOtherBranches := ExcludeOtherBranches;
  FRootDirectory := RootDirectory;
  BuildTree(RootDirectory, ExcludeOtherBranches);

  TempPath := IncludeTrailingBackslash(Copy(DirectoryPath, 4, Length(DirectoryPath)));
  if ExcludeOtherBranches and (Pos('\', TempPath) > 0) then
    TempPath := Copy(TempPath, Pos('\', TempPath) + 1, Length(TempPath));

  CurNode := GetFirst;
  while Pos('\', TempPath) > 0 do
  begin
    Directory := Copy(TempPath, 1, Pos('\', TempPath)-1);

    Data := GetNodeData(CurNode);
    while Assigned(CurNode) and (AnsiCompareText(Directory, Data.Filename) <> 0) do
    begin
      CurNode := CurNode.NextSibling;
      Data := GetNodeData(CurNode);
    end;

    if Assigned(CurNode) then
    begin
      Selected[CurNode] := True;
      Expanded[CurNode] := True;
      CurNode := CurNode.FirstChild;
    end;

    TempPath := Copy(TempPath, Pos('\', TempPath) + 1, Length(TempPath));
  end;
  EndUpdate;
end;

function DelSlash(Path: string): string;
begin
  Result := Path;
  if Path <> '' then
    if Path[Length(Path)] = '\' then
      Delete(Result, Length(Path), 1);
end;

function StrContains(Str1, Str2: string): Boolean;
var
  i: Integer;
begin
  for i := 1 to Length(Str1) do
    if Pos(Str1[i], Str2) <> 0 then
    begin
      Result := True;
      Exit;
    end;
  Result := False;
end;

function AddNullToStr(Path: string): string; //70
begin
  if Path = '' then exit;
  if Path[Length(Path)] <> #0 then
    Result := Path + #0
  else
    Result := Path;
end;

function DoSHFileOp(OpMode: UInt; Src: string; Dest: string; var Aborted: Boolean): Boolean;
var
  ipFileOp: TSHFileOpStruct;
begin
  Src := AddNullToStr(Src);
  Dest := AddNullToStr(Dest);
  FillChar(ipFileOp, SizeOf(ipFileOp), 0);
  with ipFileOp do
  begin
    wnd := GetActiveWindow;
    wFunc := OpMode;
    pFrom := pChar(Src);
    pTo := pChar(Dest);
    fFlags := FOF_ALLOWUNDO;
    fAnyOperationsAborted := Aborted;
    hNameMappings := nil;
    lpszProgressTitle := '';
  end;
  Result := SHFileOperation(ipFileOp) = 0;
  if ipFileOp.fAnyOperationsAborted = True then
    Result := False;
end;

procedure TBCFileTreeView.RenameSelectedNode;
var
  SelectedNode: PVirtualNode;
begin
  SelectedNode := GetFirstSelected;
  if Assigned(SelectedNode) then
    Self.EditNode(SelectedNode, -1)
end;

function TBCFileTreeView.DeleteTreeNode(Node: PVirtualNode): Boolean;
var
  DelName: string;
  PrevNode, SelectedNode: PVirtualNode;
  oldCur: TCursor;
  Aborted: Boolean;
  Data: PBCFileTreeNodeRec;
begin
  Result := False;
  Aborted := True;
  PrevNode := Node.Parent;
  oldCur := Screen.Cursor;
  SelectedNode := GetFirstSelected;
  if Assigned(Node) then
  try
    Screen.Cursor := crHourGlass;
    if Assigned(SelectedNode) then
    begin
      Data := GetNodeData(SelectedNode);
      if Data.FileType = ftDirectory then
        DelName := SelectedPath
      else
        DelName := SelectedFile;
    end;

    if DelName = '' then
      exit;

    DelName := DelSlash(DelName);

    if DoSHFileOp(FO_DELETE, DelName, '', Aborted) then
    begin
      if Assigned(PrevNode) then
        Selected[PrevNode] := True;
      DeleteNode(Node);
    end;
  finally
    Screen.Cursor := oldCur;
  end;
end;

procedure TBCFileTreeView.DeleteSelectedNode;
var
  SelectedNode: PVirtualNode;
begin
  SelectedNode := GetFirstSelected;
  if Assigned(SelectedNode) then
    DeleteTreeNode(SelectedNode);
end;

function IsDirectoryEmpty(const directory : string) : boolean;
var
  SearchRec :TSearchRec;
begin
  try
    Result := (FindFirst(directory+'\*.*', faAnyFile, searchRec) = 0) and
      (FindNext(searchRec) = 0) and (FindNext(searchRec) <> 0);
  finally
    System.SysUtils.FindClose(searchRec);
  end;
end;

procedure TBCFileTreeView.DoInitNode(Parent, Node: PVirtualNode; var InitStates: TVirtualNodeInitStates);
var
  Data: PBCFileTreeNodeRec;
begin
  inherited;
  Data := GetNodeData(Node);
  if Data.FileType = ftDirectory then
    if not IsDirectoryEmpty(Data.FullPath) then
      Include(InitStates, ivsHasChildren);
end;

procedure TBCFileTreeView.DoFreeNode(Node: PVirtualNode);
var
  Data: PBCFileTreeNodeRec;
begin
  inherited;
  Data := GetNodeData(Node);
  Finalize(Data^);
end;

procedure TBCFileTreeView.DoPaintNode(var PaintInfo: TVTPaintInfo);
var
  Data: PBCFileTreeNodeRec;
  S: UnicodeString;
  R: TRect;
  LStyles: TCustomStyleServices;
  LDetails: TThemedElementDetails;
  LColor: TColor;
begin
  inherited;
  LStyles := StyleServices;
  with PaintInfo do
  begin
    Data := GetNodeData(Node);
    if not Assigned(Data) then
      Exit;

    Canvas.Font.Color := clWindowText;
    Canvas.Font.Style := [];
    if LStyles.Enabled then
      Color := LStyles.GetStyleColor(scEdit);

    if LStyles.Enabled and (vsSelected in PaintInfo.Node.States) then
    begin
      R := ContentRect;
      R.Right := R.Left + NodeWidth;

      LDetails := LStyles.GetElementDetails(tgCellSelected);
      LStyles.DrawElement(Canvas.Handle, LDetails, R);
    end;

    if not LStyles.GetElementColor(LStyles.GetElementDetails(tgCellNormal), ecTextColor, LColor) or  (LColor = clNone) then
      LColor := LStyles.GetSystemColor(clWindowText);
    //get and set the background color
    Canvas.Brush.Color := LStyles.GetStyleColor(scEdit);
    Canvas.Font.Color := LColor;

    if LStyles.Enabled and (vsSelected in PaintInfo.Node.States) then
    begin
       Canvas.Brush.Color := LStyles.GetSystemColor(clHighlight);
       Canvas.Font.Color := LStyles.GetStyleFontColor(sfMenuItemTextSelected);// GetSystemColor(clHighlightText);
    end
    else
    if not LStyles.Enabled and (vsSelected in PaintInfo.Node.States) then
    begin
      Canvas.Brush.Color := clHighlight;
      Canvas.Font.Color := clHighlightText;
    end;

    SetBKMode(Canvas.Handle, TRANSPARENT);

    R := ContentRect;
    InflateRect(R, -TextMargin, 0);
    Dec(R.Right);
    Dec(R.Bottom);

    S := Data.Filename;
    if Length(S) > 0 then
    begin
      with R do
      begin
        if (NodeWidth - 2 * Margin) > (Right - Left) then
          S := ShortenString(Canvas.Handle, S, Right - Left);
      end;
      DrawTextW(Canvas.Handle, PWideChar(S), Length(S), R, DT_TOP or DT_LEFT or DT_VCENTER or DT_SINGLELINE);
    end;
  end;
end;

function TBCFileTreeView.DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var Index: Integer): TCustomImageList;
var
  Data: PBCFileTreeNodeRec;
begin
  Result := inherited;
  if not Assigned(Result) then
  begin
    Data := GetNodeData(Node);
    case Kind of
      ikNormal,
      ikSelected:
        begin
          if Expanded[Node] then
            Index := Data.OpenIndex
          else
            Index := Data.CloseIndex;
        end;
    end;
  end;
end;

function TBCFileTreeView.DoCompare(Node1, Node2: PVirtualNode; Column: TColumnIndex): Integer;
var
  Data1, Data2: PBCFileTreeNodeRec;
begin
  Result := inherited;

  if Result = 0 then
  begin
    Data1 := GetNodeData(Node1);
    Data2 := GetNodeData(Node2);

    Result := -1;

    if not Assigned(Data1) or not Assigned(Data2) then
      Exit;

   if Data1.FileType <> Data2.FileType then
    begin
     if Data1.FileType = ftDirectory then
       Result := -1
     else
       Result := 1;
    end
    else
      Result := AnsiCompareText(Data1.Filename, Data2.Filename);
  end;
end;

function TBCFileTreeView.DoGetNodeWidth(Node: PVirtualNode; Column: TColumnIndex; Canvas: TCanvas = nil): Integer;
var
  Data: PBCFileTreeNodeRec;
begin
  Result := inherited;
  Data := GetNodeData(Node);
  if Canvas = nil then
    Canvas := Self.Canvas;
  if Assigned(Data) then
    Result := Canvas.TextWidth(Trim(Data.FileName)) + 2 * TextMargin;
end;

procedure TBCFileTreeView.DoInitChildren(Node: PVirtualNode; var ChildCount: Cardinal);
var
  Data, ChildData: PBCFileTreeNodeRec;
  SR: TSearchRec;
  ChildNode: PVirtualNode;
  FName: String;
begin
  Data := GetNodeData(Node);

  if FindFirst(IncludeTrailingBackslash(Data.FullPath) + '*.*', faAnyFile, SR) = 0 then
  begin
    Screen.Cursor := crHourGlass;
    try
      repeat
        {$WARNINGS OFF}
        if ((SR.Attr and faHidden <> 0) and not ShowHiddenFiles) or
          ((SR.Attr and faArchive <> 0) and not ShowArchiveFiles) or
          ((SR.Attr and faSysFile <> 0) and not ShowSystemFiles) then
          Continue;
        {$WARNINGS ON}
        FName := IncludeTrailingBackslash(Data.FullPath) + SR.Name; //StrPas(Win32FD.cFileName);
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          ChildNode := AddChild(Node);
          //Include(ChildNode.States, vsInitialUserData);
          ChildData := GetNodeData(ChildNode);

          if (SR.Attr and faDirectory <> 0) then
          begin
            ChildData.FileType := ftDirectory;
            ChildData.FullPath := IncludeTrailingBackslash(FName);
          end
          else
          begin
            ChildData.FileType := ftFile;
            ChildData.FullPath := IncludeTrailingBackslash(Data.FullPath);
          end;
          ChildData.Filename := SR.Name;
          ChildData.CloseIndex := GetOpenIcon(FName);
          ChildData.OpenIndex := GetCloseIcon(FName);
          ValidateNode(Node, False);
        end;
      until FindNext(SR) <> 0;

      ChildCount := Self.ChildCount[Node];

      if ChildCount > 0 then
        Sort(Node, 0, sdAscending, False);
    finally
      System.SysUtils.FindClose(SR);
      Screen.Cursor := crDefault;
    end;
  end;
end;

function TBCFileTreeView.DoCreateEditor(Node: PVirtualNode; Column: TColumnIndex): IVTEditLink;
begin
  Result := TEditLink.Create;
end;

{ TEditLink }

destructor TEditLink.Destroy;
begin
  //FEdit.Free;
  inherited;
end;

procedure TEditLink.EditKeyPress(Sender: TObject; var Key: Char);
begin
  case Key of
    #27:
      begin
        FTree.CancelEditNode;
        Key := #0;
      end;
    #13:
      begin
        FTree.EndEditNode;
        Key := #0;
      end;
  end;
end;

function TEditLink.BeginEdit: Boolean;
begin
  Result := True;
  FEdit.Show;
  FEdit.SetFocus;
end;

function TEditLink.CancelEdit: Boolean;
begin
  Result := True;
  FEdit.Hide;
end;

function TEditLink.EndEdit: Boolean;
var
  Data: PBCFileTreeNodeRec;
  Buffer: array[0..254] of Char;
  S, OldDirName, NewDirName: UnicodeString;
  Aborted: Boolean;
begin
  Result := True;

  Data := FTree.GetNodeData(FNode);
  try
    GetWindowText(FEdit.Handle, Buffer, 255);
    S := Buffer;

    if (Length(S) = 0) or (StrContains('\*?/="<>|:,;+^', S)) then
    begin
      MessageBeep(MB_ICONHAND);
      if Length(S) > 0 then
        MessageDlg(Format('%s %s', [LanguageDataModule.GetConstant('InvalidName'), S]), mtError, [mbOK], 0);
      Exit;
    end;

    OldDirName := Data.FullPath + Data.Filename;
    NewDirName := Data.FullPath + S;
    if OldDirName = NewDirName then
      Exit;
    if MessageDlg(Format(LanguageDataModule.GetConstant('Rename'), [ExtractFileName(OldDirName),
      ExtractFileName(NewDirName)]), mtConfirmation, [mbYes, mbNo], 0) = mrNo then
      Exit;
    FTree.SetFocus;
    try
      DoSHFileOp(FO_RENAME, OldDirName, NewDirName, Aborted);
    except

    end;
    if S <> Data.FileName then
    begin
      Data.FileName := S;
      FTree.InvalidateNode(FNode);
    end;
  finally
    FEdit.Hide;
    FTree.SetFocus;
  end;
end;

function TEditLink.GetBounds: TRect;
begin
  Result := FEdit.BoundsRect;
end;

function TEditLink.PrepareEdit(Tree: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex): Boolean;
var
  Data: PBCFileTreeNodeRec;
begin
  Result := True;
  FTree := Tree as TBCFileTreeView; //TVirtualDrawTree;
  FNode := Node;
  FColumn := Column;

  FEdit.Free;
  FEdit := nil;
  Data := FTree.GetNodeData(Node);

  FEdit := TBCEdit.Create(nil);
  with FEdit do
  begin
    Visible := False;
    Parent := Tree;
    FEdit.Font.Name := FTree.Canvas.Font.Name;
    FEdit.Font.Size := FTree.Canvas.Font.Size;
    Flat := True;
    Text := Data.FileName;
    OnKeyPress := EditKeyPress;
  end;
end;

procedure TEditLink.ProcessMessage(var Message: TMessage);
begin
  FEdit.WindowProc(Message);
end;

procedure TEditLink.SetBounds(R: TRect);
var
  Dummy: Integer;
begin
  // Since we don't want to activate grid extensions in the tree (this would influence how the selection is drawn)
  // we have to set the edit's width explicitly to the width of the column.
  FTree.Header.Columns.GetColumnBounds(FColumn, Dummy, R.Right);
  FEdit.BoundsRect := R;
end;

end.