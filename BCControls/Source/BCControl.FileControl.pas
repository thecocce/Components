unit BCControl.FileControl;

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls, Winapi.Messages, System.Types,
  Winapi.Windows, VirtualTrees, Vcl.ImgList, BCControl.Edit, Vcl.ExtCtrls, {sCommonData,} sComboBox,
  System.UITypes, sSkinManager;

type
  TBCFileTreeView = class;

  TDriveComboFile = class
    Drive: string;
    IconIndex: Integer;
    FileName: string;
  end;

  TBCCustomDriveComboBox = class(TsCustomComboBox)
  private
    FDrive: Char;
    FIconIndex: Integer;
    FFileTreeView: TBCFileTreeView;
    FSystemIconsImageList: TImageList;
    { Can't use Items.Objects because those objects can't be destroyed in destructor because control has no parent
      window anymore. }
    FDriveComboFileList: TList;
    procedure SetFileTreeView(Value: TBCFileTreeView);
    procedure GetSystemIcons;
    procedure ResetItemHeight;
    function GetDrive: Char;
    procedure SetDrive(NewDrive: Char);
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
  protected
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure Change; override;
    procedure BuildList; virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearItems;
    property Drive: Char read GetDrive write SetDrive;
    property FileTreeView: TBCFileTreeView read FFileTreeView write SetFileTreeView;
    property SystemIconsImageList: TImageList read FSystemIconsImageList;
    property IconIndex: Integer read FIconIndex;
  end;

  TBCDriveComboBox = class(TBCCustomDriveComboBox)
  published
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

  TBCCustomFileTypeComboBox = class(TsCustomComboBox)
  private
    FFileTreeViewUpdateDelay: Integer;
    FFileTreeView: TBCFileTreeView;
    FFileTreeViewUpdateTimer: TTimer;
    function GetFileType: string;
    procedure ResetItemHeight;
    procedure SetFileTreeView(Value: TBCFileTreeView);
    procedure SetFileTreeViewUpdateDelay(Value: Integer);
    procedure SetExtensions(Value: string);
    procedure SetFileType(Value: string);
    procedure UpdateVirtualTree;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure OnFileTreeViewUpdateDelayTimer(Sender: TObject);
    procedure CNDrawItem(var Message: TWMDrawItem); message CN_DRAWITEM;
  protected
    procedure Change; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Extensions: string write SetExtensions;
    property FileTreeViewUpdateDelay: Integer read FFileTreeViewUpdateDelay write SetFileTreeViewUpdateDelay;
    property FileTreeView: TBCFileTreeView read FFileTreeView write SetFileTreeView;
    property FileType: string read GetFileType write SetFileType;
  end;

  TBCFileTypeComboBox = class(TBCCustomFileTypeComboBox)
  published
    property Align;
    property Anchors;
    property AutoComplete;
    property AutoDropDown;
    property Color;
    property Constraints;
    property FileTreeViewUpdateDelay;
    property FileTreeView;
    property FileType;
    property DoubleBuffered;
    property DragMode;
    property DragCursor;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentDoubleBuffered;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property SkinData;
    property TabOrder;
    property TabStop;
    property Text;
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

  TBCFileType = (ftNone, ftDirectory, ftFile, ftDirectoryAccessDenied, ftFileAccessDenied);

  PBCFileTreeNodeRec = ^TBCFileTreeNodeRec;
  TBCFileTreeNodeRec = record
    FileType: TBCFileType;
    SaturateImage: Boolean;
    FullPath, Filename: string;
    ImageIndex, SelectedIndex, OverlayIndex: Integer;
  end;

  TBCFileTreeView = class(TVirtualDrawTree)
  private
    FDrive: Char;
    FDriveComboBox: TBCCustomDriveComboBox;
    FFileType: string;
    FFileTypeComboBox: TBCCustomFileTypeComboBox;
    FShowHidden: Boolean;
    FShowSystem: Boolean;
    FShowArchive: Boolean;
    FShowOverlayIcons: Boolean;
    FRootDirectory: string;
    FDefaultDirectoryPath: string;
    FExcludeOtherBranches: Boolean;
    FSkinManager: TsSkinManager;
    procedure DriveChange(NewDrive: Char);
    procedure SetDrive(Value: Char);
    procedure SetFileType(NewFileType: string);
    function GetAImageIndex(Path: string): Integer;
    function GetSelectedIndex(Path: string): Integer;
    function GetFileType: string;
    function GetDrive: Char;
    procedure BuildTree(RootDirectory: string; ExcludeOtherBranches: Boolean);
    function GetSelectedPath: string;
    function GetSelectedFile: string;
    function IsDirectoryEmpty(const Directory: string): Boolean;
    function GetDriveRemote: Boolean;
  protected
    function DeleteTreeNode(Node: PVirtualNode): Boolean;
    procedure DoInitNode(Parent, Node: PVirtualNode; var InitStates: TVirtualNodeInitStates); override;
    procedure DoFreeNode(Node: PVirtualNode); override;
    procedure DoPaintNode(var PaintInfo: TVTPaintInfo); override;
    function DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
      var Ghosted: Boolean; var Index: TImageIndex): TCustomImageList; override;
    function DoCompare(Node1, Node2: PVirtualNode; Column: TColumnIndex): Integer; override;
    function DoGetNodeWidth(Node: PVirtualNode; Column: TColumnIndex; Canvas: TCanvas = nil): Integer; override;
    function DoInitChildren(Node: PVirtualNode; var ChildCount: Cardinal): Boolean; override;
    function DoCreateEditor(Node: PVirtualNode; Column: TColumnIndex): IVTEditLink; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure PaintImage(var PaintInfo: TVTPaintInfo; ImageInfoIndex: TVTImageInfoIndex; DoOverlay: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure CreateWnd; override;
    procedure OpenPath(ARootDirectory: string; ADirectoryPath: string; AExcludeOtherBranches: Boolean;
      ARefresh: Boolean = False);
    procedure RenameSelectedNode;
    procedure DeleteSelectedNode;
    property Drive: Char read GetDrive write SetDrive;
    property FileType: string read GetFileType write SetFileType;
    property ShowHiddenFiles: Boolean read FShowHidden write FShowHidden;
    property ShowSystemFiles: Boolean read FShowSystem write FShowSystem;
    property ShowArchiveFiles: Boolean read FShowArchive write FShowArchive;
    property ShowOverlayIcons: Boolean read FShowOverlayIcons write FShowOverlayIcons;
    property ExcludeOtherBranches: Boolean read FExcludeOtherBranches;
    property SelectedPath: string read GetSelectedPath;
    property SelectedFile: string read GetSelectedFile;
    property RootDirectory: string read FRootDirectory;
    property SkinManager: TsSkinManager read FSkinManager write FSkinManager;
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
    procedure Copy;
    procedure Paste;
    procedure Cut;
  end;

implementation

uses
  Vcl.Forms, Winapi.ShellAPI, Vcl.Dialogs, BCControl.Utils, BCControl.Language, BCControl.ImageList,
  Winapi.CommCtrl, VirtualTrees.Utils, sGraphUtils, sVCLUtils, sDefaults;

const
  FILE_ATTRIBUTES = FILE_ATTRIBUTE_READONLY or FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM or FILE_ATTRIBUTE_ARCHIVE or FILE_ATTRIBUTE_NORMAL or FILE_ATTRIBUTE_DIRECTORY;

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
  Autosize := False;
  Style := csOwnerDrawFixed;
  GetSystemIcons;
  GetDir(0, Temp);
  FDrive := Temp[1]; { make default drive selected }
  if FDrive = '\' then
    FDrive := #0;
  ResetItemHeight;
  FDriveComboFileList := TList.Create;
end;

destructor TBCCustomDriveComboBox.Destroy;
begin
  if not (csDesigning in ComponentState) then
  begin
    ClearItems;
    FreeAndNil(FDriveComboFileList);
  end;
  FreeAndNil(FSystemIconsImageList);
  inherited Destroy;
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

  ClearItems;
  Integer(Drives) := GetLogicalDrives;

  for lp1 := 0 to 25 do
  begin
    if (lp1 in Drives) then
    begin
      Drv := chr(ord('A') + lp1) + ':\';
      SHGetFileInfo(PChar(Drv), 0, SHFileInfo, SizeOf(SHFileInfo), SHGFI_SYSICONINDEX or SHGFI_DISPLAYNAME or SHGFI_TYPENAME);
      DriveComboFile := TDriveComboFile.Create;
      DriveComboFile.Drive := chr(ord('A') + lp1);
      DriveComboFile.IconIndex := SHFileInfo.iIcon;
      DriveComboFile.FileName := StrPas(SHFileInfo.szDisplayName);
      Items.Add(StrPas(SHFileInfo.szDisplayName));
      FDriveComboFileList.Add(DriveComboFile);
      { destroy the icon, we are only using the index }
      DestroyIcon(SHFileInfo.hIcon);
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
      if UpCase(NewDrive) = TDriveComboFile(FDriveComboFileList[Item]).Drive then
      begin
        ItemIndex := Item;
        Break;
      end;
    if ItemIndex <> -1 then
      FIconIndex := TDriveComboFile(FDriveComboFileList[ItemIndex]).IconIndex;
    if Assigned(FFileTreeView) then
      FFileTreeView.DriveChange(NewDrive);
    Change;
  end;
end;

procedure TBCCustomDriveComboBox.SetFileTreeView(Value: TBCFileTreeView);
begin
  if Assigned(FFileTreeView) then
    FFileTreeView.FDriveComboBox := nil;
  FFileTreeView := Value;
  if Assigned(FFileTreeView) then
  begin
    FFileTreeView.FDriveComboBox := Self;
    FFileTreeView.FreeNotification(Self);
  end;
end;

procedure TBCCustomDriveComboBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  if Index = -1 then
    Exit;
  { ensure the correct highlite color is used }
  if Assigned(SkinData) and Assigned(SkinData.SkinManager) and SkinData.SkinManager.Active then
  begin
    if odSelected in State then
    begin
      Canvas.Brush.Color := SkinData.SkinManager.GetHighLightColor;
      Canvas.Font.Color := SkinData.SkinManager.GetHighLightFontColor
    end
    else
    begin
      Canvas.Brush.Color := SkinData.SkinManager.gd[SkinData.SkinIndex].Props[0].Color;
      Canvas.Font.Color := SkinData.SkinManager.GetActiveEditFontColor;
    end;
  end;
  Canvas.FillRect(Rect);
  if FDriveComboFileList.Count > 0 then
  begin
    { draw the actual bitmap }
    FSystemIconsImageList.Draw(Canvas, Rect.Left + 3, Rect.Top, TDriveComboFile(FDriveComboFileList[Index]).IconIndex);
    { write the text }
    Canvas.TextOut(Rect.Left + FSystemIconsImageList.Width + 7, Rect.Top + 2,
      TDriveComboFile(FDriveComboFileList[Index]).FileName);
  end;
end;

procedure TBCCustomDriveComboBox.Change;
begin
  inherited;
  if ItemIndex >= 0 then
    if Assigned(FDriveComboFileList[ItemIndex]) then
      Drive := TDriveComboFile(FDriveComboFileList[ItemIndex]).Drive[1];
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
  nuHeight := GetItemHeight(Font);
  if nuHeight < FSystemIconsImageList.Height then
    nuHeight := FSystemIconsImageList.Height;
  ItemHeight := nuHeight;
end;

procedure TBCCustomDriveComboBox.GetSystemIcons;
begin
  FSystemIconsImageList := TImageList.Create(Self);
  FSystemIconsImageList.Handle := GetSysImageList;
end;

procedure TBCCustomDriveComboBox.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FFileTreeView) then
    FFileTreeView := nil;
end;

procedure TBCCustomDriveComboBox.ClearItems;
var
  i: Integer;
begin
   if not (csDesigning in ComponentState) then
  begin
    for i := 0 to FDriveComboFileList.Count - 1 do
      TDriveComboFile(FDriveComboFileList.Items[i]).Free;
    FDriveComboFileList.Clear;
    if not (csDestroying in ComponentState) then
      Clear; // can't clear if the component is being destroyed or there is an exception, 'no parent window'
  end;
end;

procedure TBCCustomDriveComboBox.CNDrawItem(var Message: TWMDrawItem);
var
  State: TOwnerDrawState;
begin
  if csDesigning in ComponentState then
    Exit;
  with Message.DrawItemStruct^ do
  begin
    State := TOwnerDrawState(LoWord(itemState));
    if ItemState and ODS_COMBOBOXEDIT <> 0 then
      Include(State, odComboBoxEdit);
    if ItemState and ODS_DEFAULT <> 0 then
      Include(State, odDefault);
    Canvas.Handle := hDC;
    Canvas.Font := Font;
   
    if Assigned(SkinData) and Assigned(SkinData.SkinManager) and SkinData.SkinManager.Active then
    begin
      Canvas.Brush.Color := SkinData.SkinManager.gd[SkinData.SkinIndex].Props[0].Color;
      Canvas.Font.Color := SkinData.SkinManager.GetActiveEditFontColor
    end
    else
    begin
      Canvas.Brush := Brush;
      Canvas.Font.Color := clWindowText;
    end;
    if (Integer(itemID) >= 0) and (odSelected in State) then
    begin
      if Assigned(SkinData) and Assigned(SkinData.SkinManager) and SkinData.SkinManager.Active then
      begin
        Canvas.Brush.Color := SkinData.SkinManager.GetHighLightColor;
        Canvas.Font.Color := SkinData.SkinManager.GetHighLightFontColor
      end
      else
      begin
        Canvas.Brush.Color := clHighlight;
        Canvas.Font.Color := clHighlightText;
      end;
    end;
    if Integer(ItemID) >= 0 then
      DrawItem(ItemID, rcItem, State)
    else
      Canvas.FillRect(rcItem);
    //if odFocused in State then DrawFocusRect(hDC, rcItem);
    Canvas.Handle := 0;
  end;
end;

{ TBCCustomFileTypeComboBox }

constructor TBCCustomFileTypeComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Autosize := False;
  FFileTreeViewUpdateDelay := 500;
  FFileTreeViewUpdateTimer := TTimer.Create(nil);
  with FFileTreeViewUpdateTimer do
  begin
    OnTimer := OnFileTreeViewUpdateDelayTimer;
    Interval := FFileTreeViewUpdateDelay;
  end;
  ResetItemHeight;
end;

destructor TBCCustomFileTypeComboBox.Destroy;
begin
  FFileTreeViewUpdateTimer.Free;
  inherited;
end;

procedure TBCCustomFileTypeComboBox.UpdateVirtualTree;
begin
  if Assigned(FFileTreeView) then
    FFileTreeView.FileType := Text;
end;

procedure TBCCustomFileTypeComboBox.SetFileTreeView(Value: TBCFileTreeView);
begin
  if Assigned(FFileTreeView) then
    FFileTreeView.FFileTypeComboBox := nil;
  FFileTreeView := Value;
  if Assigned(FFileTreeView) then
  begin
    FFileTreeView.FFileTypeComboBox := Self;
    FFileTreeView.FreeNotification(Self);
  end;
end;

procedure TBCCustomFileTypeComboBox.SetFileTreeViewUpdateDelay(Value: Integer);
begin
  FFileTreeViewUpdateDelay := Value;
  if Assigned(FFileTreeViewUpdateTimer) then
    FFileTreeViewUpdateTimer.Interval := Value;
end;

procedure TBCCustomFileTypeComboBox.CMFontChanged(var Message: TMessage);
begin
  inherited;
  ResetItemHeight;
  RecreateWnd;
end;

function TBCCustomFileTypeComboBox.GetFileType: string;
begin
  Result := Text;
end;

procedure TBCCustomFileTypeComboBox.SetFileType(Value: string);
begin
  Text := Value;
end;

procedure TBCCustomFileTypeComboBox.ResetItemHeight;
begin
  ItemHeight := GetItemHeight(Font);
end;

procedure TBCCustomFileTypeComboBox.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FFileTreeView) then
    FFileTreeView := nil;
end;

procedure TBCCustomFileTypeComboBox.Change;
begin
  inherited;
  with FFileTreeViewUpdateTimer do
  begin
    Enabled := False; { change starts the delay timer again }
    Enabled := True;
  end;
end;

procedure TBCCustomFileTypeComboBox.OnFileTreeViewUpdateDelayTimer(Sender: TObject);
begin
  FFileTreeViewUpdateTimer.Enabled := False;
  UpdateVirtualTree;
end;

procedure TBCCustomFileTypeComboBox.SetExtensions(Value: string);
var
  Temp: string;
begin
  Temp := Value;
  with Items do
  begin
    Clear;
    while Pos('|', Temp) <> 0 do
    begin
      Add(Copy(Temp, 1, Pos('|', Temp) - 1));
      Temp := Copy(Temp, Pos('|', Temp) + 1, Length(Temp));
    end;
  end;
end;

procedure TBCCustomFileTypeComboBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  { ensure the correct highlite color is used }
  Canvas.FillRect(Rect);
  { write the text }
  Canvas.TextOut(Rect.Left, Rect.Top + 2, Items[Index]);
end;

procedure TBCCustomFileTypeComboBox.CNDrawItem(var Message: TWMDrawItem);
var
  State: TOwnerDrawState;
begin
  with Message.DrawItemStruct{$IFNDEF CLR}^{$ENDIF} do
  begin
    State := TOwnerDrawState(LoWord(itemState));
    if itemState and ODS_COMBOBOXEDIT <> 0 then
      Include(State, odComboBoxEdit);
    if itemState and ODS_DEFAULT <> 0 then
      Include(State, odDefault);
    Canvas.Handle := hDC;
    Canvas.Font := Font;
    Canvas.Brush := Brush;

    if Assigned(SkinData) and Assigned(SkinData.SkinManager) and SkinData.SkinManager.Active then
      Canvas.Font.Color := SkinData.SkinManager.GetActiveEditFontColor
    else
      Canvas.Font.Color := clWindowText;
    if (Integer(itemID) >= 0) and (odSelected in State) then
    begin
      if Assigned(SkinData) and Assigned(SkinData.SkinManager) and SkinData.SkinManager.Active then
      begin
        Canvas.Brush.Color := SkinData.SkinManager.GetHighLightColor;
        Canvas.Font.Color := SkinData.SkinManager.GetHighLightFontColor
      end
      else
      begin
        Canvas.Brush.Color := clHighlight;
        Canvas.Font.Color := clHighlightText;
      end;
    end;
    if Integer(itemID) >= 0 then
      DrawItem(itemID, rcItem, State)
    else
      Canvas.FillRect(rcItem);
    //if odFocused in State then DrawFocusRect(hDC, rcItem);
    Canvas.Handle := 0;
  end;
end;

{ TBCFileTreeView }

constructor TBCFileTreeView.Create;
var
  SysImageList: THandle;
begin
  inherited Create(AOwner);

  //FCommonData := TsCtrlSkinData.Create(Self, True);

  DragOperations := [];
  Header.Options := [];
  IncrementalSearch := isAll;
  Indent := 20;
  EditDelay := 500;

  TreeOptions.AutoOptions := [toAutoDropExpand, toAutoScroll, toAutoChangeScale, toAutoScrollOnExpand, toAutoTristateTracking, toAutoDeleteMovedNodes];
  TreeOptions.MiscOptions := [toEditable, toFullRepaintOnResize, toInitOnSave, toToggleOnDblClick, toWheelPanning, toEditOnClick];
  TreeOptions.PaintOptions := [toShowBackground, toShowButtons, toShowRoot, toThemeAware, toHideTreeLinesIfThemed, toUseExplorerTheme];

  FShowHidden := False;
  FShowArchive := True;
  FShowSystem := False;
  FShowOverlayIcons := True;

  Images := TImageList.Create(Self);
  SysImageList := GetSysImageList;
  if SysImageList <> 0 then
  begin
    Images.Handle := SysImageList;
    Images.BkColor := clNone;
    Images.ShareImages := True;
  end;

  FDrive := #0;
  FFileType := '*.*';
end;

procedure TBCFileTreeView.CreateWnd;
begin
  inherited;
  {FCommonData.Loaded;

  if HandleAllocated and FCommonData.Skinned then begin
    if not FCommonData.CustomColor then
      Color := FCommonData.SkinManager.gd[FCommonData.SkinIndex].Props[0].Color;

    if not FCommonData.CustomFont then
      Font.Color := FCommonData.SkinManager.gd[FCommonData.SkinIndex].Props[0].FontColor.Color;
  end;    }
end;

destructor TBCFileTreeView.Destroy;
begin
  Images.Free;
  //if Assigned(FCommonData) then
  //  FreeAndNil(FCommonData);

  inherited Destroy;
end;

procedure TBCFileTreeView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FDriveComboBox then
      FDriveComboBox := nil
    else
    if AComponent = FFileTypeComboBox then
      FFileTypeComboBox := nil
  end;
end;

procedure TBCFileTreeView.DriveChange(NewDrive: Char);
begin
  if UpCase(NewDrive) <> UpCase(FDrive) then
  begin
    FDrive := NewDrive;
    FRootDirectory := NewDrive + ':\';
    if not (csDesigning in ComponentState) then
      BuildTree(FRootDirectory, False);
  end
end;

procedure TBCFileTreeView.SetFileType(NewFileType: string);
begin
  if AnsiUpperCase(NewFileType) <> AnsiUpperCase(FFileType) then
  begin
    FFileType := NewFileType;
    if not (csDesigning in ComponentState) then
      OpenPath(FRootDirectory, SelectedPath, FExcludeOtherBranches);
  end
end;

function TBCFileTreeView.GetFileType: string;
begin
  Result := FFileType;
end;

procedure TBCFileTreeView.SetDrive(Value: Char);
begin
  if (UpCase(Value) <> UpCase(FDrive)) then
  begin
    FDrive := Value;
    DriveChange(Value);
  end;
end;

function TBCFileTreeView.GetDrive: Char;
begin
  Result := FDrive;
end;

function TBCFileTreeView.GetAImageIndex(Path: string): Integer;
begin
  Result := GetIconIndex(Path);
end;

function TBCFileTreeView.GetSelectedIndex(Path: string): Integer;
begin
  Result := GetIconIndex(Path, SHGFI_OPENICON);
end;

function TBCFileTreeView.GetDriveRemote: Boolean;
var
  LDrive: string;
  LDriveType: Cardinal;
begin
  { Access check for remote drive is impossible

    Even when performing AccessCheck(), you are doing an access check against an access token that is generated "locally",
    with the security descriptor associated with the object. When you directly access the object on a remote system, a network
    access token gets generated on the remote system. This network access token is used to perform access check on the object
    to determine whether access should be granted or denied. The object could be either a file or named pipe or AD object.

    e.g. If the user is member of Administrators group on the remote system, when you directly access the object on a remote
    system, the network access token that gets generated on the remote system will have Administrators group and will allow access.
    Whereas, when you call AccessCheck() with a local access token, you will get different results. }
  LDrive := GetDrive + ':\';
  LDriveType := GetDriveType(PChar(LDrive));
  Result := LDriveType = DRIVE_REMOTE;
end;

procedure TBCFileTreeView.BuildTree(RootDirectory: string; ExcludeOtherBranches: Boolean);
var
  FindFile: Integer;
  ANode: PVirtualNode;
  SR: TSearchRec;
  FileName: string;
  Data: PBCFileTreeNodeRec;
  DriveRemote: Boolean;
  LRootDirectory: string;
begin
  BeginUpdate;
  ANode := GetFirst;
  if Assigned(ANode) then
    Clear;
  NodeDataSize := SizeOf(TBCFileTreeNodeRec);

  DriveRemote := GetDriveRemote;
  {$WARNINGS OFF} { IncludeTrailingBackslash is specific to a platform }
  LRootDirectory := IncludeTrailingBackslash(RootDirectory);
  {$WARNINGS ON}

  if not ExcludeOtherBranches then
    FindFile := FindFirst(GetDrive + ':\*.*', faAnyFile, SR)
  else
    FindFile := FindFirst(LRootDirectory + '*.*', faAnyFile, SR);

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
        if (SR.Attr and faDirectory <> 0) or (FFileType = '*.*') or IsExtInFileType(ExtractFileExt(SR.Name), FFileType) then
        begin
          ANode := AddChild(nil);

          Data := GetNodeData(ANode);
          if not ExcludeOtherBranches then
            FileName := GetDrive + ':\' + SR.Name
          else
            {$WARNINGS OFF}
            FileName := LRootDirectory + SR.Name;
            {$WARNINGS ON}
          if (SR.Attr and faDirectory <> 0) then
          begin
            Data.FileType := ftDirectory;
            {$WARNINGS OFF}
            Data.FullPath := IncludeTrailingBackslash(FileName);
            {$WARNINGS ON}
          end
          else
          begin
            Data.FileType := ftFile;
            if not ExcludeOtherBranches then
              Data.FullPath := GetDrive + ':\'
            else
              Data.FullPath := LRootDirectory;
          end;
          if not DriveRemote then
            if not CheckAccessToFile(FILE_GENERIC_READ, Filename) then //Data.FullPath) then
            begin
              if Data.FileType = ftDirectory then
                Data.FileType := ftDirectoryAccessDenied
              else
                Data.FileType := ftFileAccessDenied;
            end;
          {$WARNINGS OFF}
          Data.SaturateImage := (SR.Attr and faHidden <> 0) or (SR.Attr and faSysFile <> 0) or
            (Data.FileType = ftDirectoryAccessDenied) or (Data.FileType = ftFileAccessDenied);
          {$WARNINGS ON}
          Data.Filename := SR.Name;
          Data.ImageIndex := GetAImageIndex(Filename);
          Data.SelectedIndex := GetSelectedIndex(Filename);
          Data.OverlayIndex := GetIconOverlayIndex(Filename);
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
    {$WARNINGS OFF} { IncludeTrailingBackslash is specific to a platform }
    Result := IncludeTrailingBackslash(Data.FullPath);
    {$WARNINGS ON}
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

  Data := GetNodeData(TreeNode);
  if Data.FileType = ftDirectory then
    Exit;

  {$WARNINGS OFF} { IncludeTrailingBackslash is specific to a platform }
  Result := IncludeTrailingBackslash(Data.FullPath);
  {$WARNINGS ON}
  if System.SysUtils.FileExists(Result + Data.Filename) then
    Result := Result + Data.Filename;
end;

procedure TBCFileTreeView.OpenPath(ARootDirectory: string; ADirectoryPath: string; AExcludeOtherBranches: Boolean;
  ARefresh: Boolean = False);
var
  CurNode: PVirtualNode;
  Data: PBCFileTreeNodeRec;
  TempPath, Directory: string;
begin
  if not DirectoryExists(ARootDirectory) then
    Exit;
  if not DirectoryExists(ExtractFileDir(ADirectoryPath)) then
    Exit;
  BeginUpdate;
  FDriveComboBox.BuildList;
  FDriveComboBox.Drive := FDrive;
  FDefaultDirectoryPath := ADirectoryPath;
  if ARefresh or (FRootDirectory <> ARootDirectory) or (FExcludeOtherBranches <> ExcludeOtherBranches) then
  begin
    FRootDirectory := ARootDirectory;
    FExcludeOtherBranches := ExcludeOtherBranches;
    BuildTree(ARootDirectory, ExcludeOtherBranches);
  end;

  {$WARNINGS OFF} { IncludeTrailingBackslash is specific to a platform }
  TempPath := IncludeTrailingBackslash(Copy(ADirectoryPath, 4, Length(ADirectoryPath)));
  {$WARNINGS ON}
  if ExcludeOtherBranches and (Pos('\', TempPath) > 0) then
    TempPath := Copy(TempPath, Pos('\', TempPath) + 1, Length(TempPath));

  CurNode := GetFirst;
  while TempPath <> '' do
  begin
    if Pos('\', TempPath) <> 0 then
      Directory := Copy(TempPath, 1, Pos('\', TempPath)-1)
    else
      Directory := TempPath;

    if Directory <> '' then
    begin
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
        ScrollIntoView(CurNode, True);
        CurNode := CurNode.FirstChild;
      end;
    end;

    if Pos('\', TempPath) <> 0 then
      TempPath := Copy(TempPath, Pos('\', TempPath) + 1, Length(TempPath))
    else
      TempPath := '';
  end;
  EndUpdate;
end;

function AddNullToStr(Path: string): string;
begin
  if Path = '' then
    Exit('');
  if Path[Length(Path)] <> #0 then
    Result := Path + #0
  else
    Result := Path;
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
  Data: PBCFileTreeNodeRec;
begin
  Result := False;
  PrevNode := Node.Parent;
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

      if DelName = '' then
        Exit;
      {$WARNINGS OFF} { ExcludeTrailingBackslash is specific to a platform }
      DelName := ExcludeTrailingBackslash(DelName);
      {$WARNINGS ON}

      if Data.FileType = ftDirectory then
        Result := RemoveDirectory(DelName)
      else
        Result := System.SysUtils.DeleteFile(DelName);
    end;
    if Result then
    begin
      if Assigned(PrevNode) then
        Selected[PrevNode] := True;
      DeleteNode(Node);
    end;
  finally
    Screen.Cursor := crDefault;
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

function TBCFileTreeView.IsDirectoryEmpty(const Directory: string): Boolean;
var
  SearchRec: TSearchRec;
begin
  try
    Result := (FindFirst(Directory + '\*.*', faAnyFile, SearchRec) = 0) and
      (FindNext(SearchRec) = 0) and (FindNext(SearchRec) <> 0);
  finally
    System.SysUtils.FindClose(SearchRec);
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
  Data := GetNodeData(Node);
  Finalize(Data^);
  inherited;
end;

procedure TBCFileTreeView.DoPaintNode(var PaintInfo: TVTPaintInfo);
var
  Data: PBCFileTreeNodeRec;
  S: string;
  R: TRect;
begin
  inherited;
  with PaintInfo do
  begin
    Data := GetNodeData(Node);
    if not Assigned(Data) then
      Exit;

    Canvas.Font.Style := [];

   if Assigned(SkinManager) then
     Canvas.Font.Color :=  SkinManager.GetActiveEditFontColor
   else
     Canvas.Font.Color := clWindowText;

    if vsSelected in PaintInfo.Node.States then
    begin
      if Assigned(SkinManager) and SkinManager.Active then
      begin
        Canvas.Brush.Color := SkinManager.GetHighLightColor;
        Canvas.Font.Color := SkinManager.GetHighLightFontColor
      end
      else
      begin
        Canvas.Brush.Color := clHighlight;
        Canvas.Font.Color := clHighlightText;
      end;
    end;
    Canvas.Font.Style := [];
    if (Data.FileType = ftDirectoryAccessDenied) or (Data.FileType = ftFileAccessDenied) then
    begin
      Canvas.Font.Style := [fsItalic];
      if Assigned(SkinManager) then
        Canvas.Font.Color := MixColors(ColorToRGB(Font.Color), GetControlColor(Parent), DefDisabledBlend)
      else
        Canvas.Font.Color := clBtnFace;
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
        if (NodeWidth - 2 * Margin) > (Right - Left) then
          S := ShortenString(Canvas.Handle, S, Right - Left);
      DrawTextW(Canvas.Handle, PWideChar(S), Length(S), R, DT_TOP or DT_LEFT or DT_VCENTER or DT_SINGLELINE);
    end;
  end;
end;

function TBCFileTreeView.DoGetImageIndex(Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var Index: TImageIndex): TCustomImageList;
var
  Data: PBCFileTreeNodeRec;
begin
  Result := inherited;
  if not Assigned(Result) then
  begin
    Data := GetNodeData(Node);
    if Assigned(Data) then
    case Kind of
      ikNormal,
      ikSelected:
        begin
          if Expanded[Node] then
            Index := Data.SelectedIndex
          else
            Index := Data.ImageIndex;
        end;
      ikOverlay:
        if FShowOverlayIcons then
          Index := Data.OverlayIndex
    end;
  end;
end;

type
  TCustomImageListCast = class(TCustomImageList);

procedure DrawSaturatedImage(ImageList: TCustomImageList; Canvas: TCanvas; X, Y, Index: Integer);
var
  Params: TImageListDrawParams;
begin
  FillChar(Params, SizeOf(Params), 0);
  Params.cbSize := SizeOf(Params);
  Params.himl := ImageList.Handle;
  Params.i := Index;
  Params.hdcDst := Canvas.Handle;
  Params.x := X;
  Params.y := Y;
  Params.fState := ILS_SATURATE;
  ImageList_DrawIndirect(@Params);
end;

procedure TBCFileTreeView.PaintImage(var PaintInfo: TVTPaintInfo; ImageInfoIndex: TVTImageInfoIndex; DoOverlay: Boolean);
var
  Data: PBCFileTreeNodeRec;
begin
  with PaintInfo do
  begin
    Data := GetNodeData(Node);

    if Data.SaturateImage then
    begin
      if DoOverlay then
        GetImageIndex(PaintInfo, ikOverlay, iiOverlay, Images)
      else
        PaintInfo.ImageInfo[iiOverlay].Index := -1;
      with ImageInfo[ImageInfoIndex] do
      begin
        DrawSaturatedImage(Images, Canvas, XPos, YPos, Index);
        if ImageInfo[iiOverlay].Index >= 15 then
          DrawSaturatedImage(ImageInfo[iiOverlay].Images, Canvas, XPos, YPos, ImageInfo[iiOverlay].Index);
      end;
    end
    else
      inherited;
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
     if (Data1.FileType = ftDirectory) or (Data1.FileType = ftDirectoryAccessDenied) then
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
  if not Assigned(Canvas) then
    Canvas := Self.Canvas;
  if Assigned(Data) then
    Result := Canvas.TextWidth(Trim(Data.FileName)) + 2 * TextMargin;
end;

function TBCFileTreeView.DoInitChildren(Node: PVirtualNode; var ChildCount: Cardinal): Boolean;
var
  Data, ChildData: PBCFileTreeNodeRec;
  SR: TSearchRec;
  ChildNode: PVirtualNode;
  FName: string;
  DriveRemote: Boolean;
  LFullPath: string;
begin
  Result := True;

  Data := GetNodeData(Node);

  DriveRemote := GetDriveRemote;

  {$WARNINGS OFF} { IncludeTrailingBackslash is specific to a platform }
  LFullPath := IncludeTrailingBackslash(Data.FullPath);
  {$WARNINGS OFF}
  if FindFirst(LFullPath + '*.*', faAnyFile, SR) = 0 then
  begin
    Screen.Cursor := crHourGlass;

    {TDirectory.GetDirectories
    TDirectory.GetFiles
    kts. BCCommon.FileUtils GetFiles  }

    try
      repeat
        {$WARNINGS OFF}
        if ((SR.Attr and faHidden <> 0) and not ShowHiddenFiles) or
          ((SR.Attr and faArchive <> 0) and not ShowArchiveFiles) or
          ((SR.Attr and faSysFile <> 0) and not ShowSystemFiles) then
          Continue;
        {$WARNINGS ON}
        FName := LFullPath + SR.Name;

        if (SR.Name <> '.') and (SR.Name <> '..') then
          if (SR.Attr and faDirectory <> 0) or (FFileType = '*.*') or IsExtInFileType(ExtractFileExt(SR.Name), FFileType) then
          begin
            ChildNode := AddChild(Node);
            ChildData := GetNodeData(ChildNode);

            if (SR.Attr and faDirectory <> 0) then
            begin
              ChildData.FileType := ftDirectory;
              {$WARNINGS OFF}
              ChildData.FullPath := IncludeTrailingBackslash(FName);
              {$WARNINGS ON}
            end
            else
            begin
              ChildData.FileType := ftFile;
              {$WARNINGS OFF}
              ChildData.FullPath := LFullPath;
              {$WARNINGS ON}
            end;
            if not DriveRemote then
              if not CheckAccessToFile(FILE_GENERIC_READ, FName) then
              begin
                if ChildData.FileType = ftDirectory then
                  ChildData.FileType := ftDirectoryAccessDenied
                else
                  ChildData.FileType := ftFileAccessDenied;
              end;
            {$WARNINGS OFF}
            ChildData.SaturateImage := (SR.Attr and faHidden <> 0) or (SR.Attr and faSysFile <> 0) or
              (ChildData.FileType = ftFileAccessDenied) or (ChildData.FileType = ftDirectoryAccessDenied);
            {$WARNINGS ON}
            ChildData.Filename := SR.Name;
            ChildData.ImageIndex := GetAImageIndex(FName);
            ChildData.SelectedIndex := GetSelectedIndex(FName);
            ChildData.OverlayIndex := GetIconOverlayIndex(FName);
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
  //FEdit.Free; This gives AV
  if FEdit.HandleAllocated then
    PostMessage(FEdit.Handle, CM_RELEASE, 0, 0);
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
  else
    inherited;
  end;
end;

function TEditLink.BeginEdit: Boolean;
var
  Data: PBCFileTreeNodeRec;
begin
  Data := FTree.GetNodeData(FNode);
  Result := (Data.FileType = ftDirectory) or (Data.FileType = ftFile);
  if Result then
  begin
    FEdit.Show;
    FEdit.SetFocus;
  end;
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
  S, OldDirName, NewDirName, FullPath: string;
begin
  Result := True;

  Data := FTree.GetNodeData(FNode);
  try
    GetWindowText(FEdit.Handle, Buffer, 255);
    S := Buffer;
    if (Length(S) = 0) or S.IsDelimiter('\*?/="<>|:,;+^', 0) then
    begin
      MessageBeep(MB_ICONHAND);
      if Length(S) > 0 then
        MessageDlg(Format('%s: %s', [SBCControlFileControlEndEditInvalidName, S]), mtError, [mbOK], 0);
      Exit;
    end;

    if Data.FileType = ftDirectory then
    {$WARNINGS OFF}
      FullPath := ExtractFilePath(ExcludeTrailingBackslash(Data.FullPath))
    {$WARNINGS ON}
    else
      FullPath := Data.FullPath;
    OldDirName := FullPath + Data.Filename;
    NewDirName := FullPath + S;
    if OldDirName = NewDirName then
      Exit;
    if MessageDlg(Format(SBCControlFileControlEndEditRename, [ExtractFileName(OldDirName),
      ExtractFileName(NewDirName)]), mtConfirmation, [mbYes, mbNo], 0) = mrNo then
      Exit;
    FTree.SetFocus;
    if System.SysUtils.RenameFile(OldDirName, NewDirName) then
    begin
      if S <> Data.FileName then
      begin
        Data.FileName := S;
        FTree.InvalidateNode(FNode);
      end;
    end
    else
      ShowMessage(Format(SBCControlFileControlEndEditRenameFailed, [OldDirName]));
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
  FTree := Tree as TBCFileTreeView;
  FNode := Node;
  FColumn := Column;

  if Assigned(FEdit) then
  begin
    FEdit.Free;
    FEdit := nil;
  end;
  Data := FTree.GetNodeData(Node);

  FEdit := TBCEdit.Create(nil);
  with FEdit do
  begin
    Visible := False;
    Parent := Tree;
    FEdit.Font.Name := FTree.Canvas.Font.Name;
    FEdit.Font.Size := FTree.Canvas.Font.Size;
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
  { Since we don't want to activate grid extensions in the tree (this would influence how the selection is drawn)
    we have to set the edit's width explicitly to the width of the column. }
  FTree.Header.Columns.GetColumnBounds(FColumn, Dummy, R.Right);
  FEdit.BoundsRect := R;
end;

procedure TEditLink.Copy;
begin
  FEdit.CopyToClipboard;
end;

procedure TEditLink.Paste;
begin
  FEdit.PasteFromClipboard;
end;

procedure TEditLink.Cut;
begin
  FEdit.CutToClipboard;
end;

end.

