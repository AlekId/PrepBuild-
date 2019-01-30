unit d_ManifestVersionInfo;

interface

uses
  Windows,
  SysUtils,
  Classes,
  xmldom,
  XMLIntf,
  msxmldom,
  XMLDoc,
  u_VersionInfo,
  i_VersionInfoAccess;

type
  IThemingAccess = interface ['{AFA7C417-A4E7-43DB-A2BF-49C2157A33E7}']
    procedure DisableTheming;
    procedure EnableTheming;
  end;

type
  Tdm_ManifestVersionInfo = class(TDataModule, IVersionInfoAccess, IThemingAccess)
    ProjDoc: TXMLDocument;
  private
    FInputFilename: string;
    FOutputFilename: string;
    FDescriptionNode: IXMLNode;
    FAssemblyIdentityNode: IXMLNode;
    function FindComCtlNode(out _DependentAssemblyNode: IXMLNode): boolean;
  protected // IInterface
    FRefCount: Integer;
    function QueryInterface(const IID: TGUID; out Obj): HResult; override; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  protected // IVersionInfoAccess
    function VerInfoFilename: string;
    procedure ReadFromFile(_VerInfo: TVersionInfo);
    procedure WriteToFile(_VerInfo: TVersionInfo);
  protected // IThemingAccess
    procedure DisableTheming;
    procedure EnableTheming;
  protected
    procedure InitVersionNodes; virtual;
  public
    constructor Create(const _ManifestFile: string; const _InputFile: string = ''); reintroduce;
  end;

implementation

{$R *.dfm}

uses
  StrUtils,
  u_dzFileUtils,
  u_dzStringUtils,
  u_dzVariantUtils,
  u_dzConvertUtils,
  u_dzTranslator;

{ Tdm_ManifestVersionInfo }

constructor Tdm_ManifestVersionInfo.Create(const _ManifestFile: string; const _InputFile: string = '');
begin
  inherited Create(nil);

  FOutputFilename := ChangeFileExt(_ManifestFile, '.manifest');
  FInputFilename := _InputFile;
  if FInputFilename = '' then
    FInputFilename := FOutputFilename;

  TFileSystem.FileExists(FInputFilename, True);

  ProjDoc.Options := ProjDoc.Options + [doNodeAutoIndent] - [doNodeAutoCreate, doAttrNull, doAutoSave];
  ProjDoc.FileName := FInputFilename;
  ProjDoc.Active := True;

  InitVersionNodes;
end;

//procedure EnumNodes(_Root: IXMLNode; const _Indent: string = '');
//var
//  i: Integer;
//begin
//  WriteLn(_Indent, _Root.NodeName);
//  for i := 0 to _Root.AttributeNodes.Count - 1 do begin
//    WriteLn(_Indent, ':', _Root.AttributeNodes[i].NodeName, '=', _Root.AttributeNodes[i].NodeValue);
//  end;
//  for i := 0 to _Root.ChildNodes.Count - 1 do begin
//    EnumNodes(_Root.ChildNodes.Nodes[i], _Indent + '  ');
//  end;
//end;

function Tdm_ManifestVersionInfo.FindComCtlNode(out _DependentAssemblyNode: IXMLNode): boolean;
var
  AssemblyNode: IXMLNode;
  DependencyNode: IXMLNode;
  DependentAssemblyNode: IXMLNode;
  AssemblyIdentityNode: IXMLNode;
begin
  Result := False;
  AssemblyNode := ProjDoc.DocumentElement;
  DependencyNode := AssemblyNode.ChildNodes.FindNode('dependency');
  while Assigned(DependencyNode) do begin
    DependentAssemblyNode := DependencyNode.ChildNodes.FindNode('dependentAssembly');
    if not Assigned(DependentAssemblyNode) then begin
      // This is an error:
      // According to https://docs.microsoft.com/en-us/windows/desktop/sbscs/application-manifests
      // the dependency node must contain at least one dependendAssembly node.
      Exit; //==>
    end;
    AssemblyIdentityNode := DependentAssemblyNode.ChildNodes.FindNode('assemblyIdentity');
    if not Assigned(AssemblyIdentityNode) then begin
      // This is an error:
      // According to https://docs.microsoft.com/en-us/windows/desktop/sbscs/application-manifests
      // the dependendAssembly node must contain exactly one assemblyIdentityNode node.
      Exit; //==>
    end;
    if not AssemblyIdentityNode.HasAttribute('name') then begin
      // this is an error
      Exit;
    end;
    if AssemblyIdentityNode.Attributes['name'] = 'Microsoft.Windows.Common-Controls' then begin
      Result := True;
      _DependentAssemblyNode := DependentAssemblyNode;
      Exit; //==>
    end;
    DependentAssemblyNode := nil;
    DependencyNode := DependencyNode.NextSibling;
  end;
end;

procedure Tdm_ManifestVersionInfo.DisableTheming;
var
  DependentAssemblyNode: IXMLNode;
  DependencyNode: IXMLNode;
  AssemblyNode: IXMLNode;
  DependencyIdx: Integer;
begin
  if not FindComCtlNode(DependentAssemblyNode) then begin
    // Node does not exist, so theming is already disabled
    Exit; //==>
  end;

  AssemblyNode := ProjDoc.DocumentElement;
  DependencyNode := DependentAssemblyNode.ParentNode;
  DependentAssemblyNode := nil;

  DependencyIdx := AssemblyNode.ChildNodes.IndexOf(DependencyNode);
  AssemblyNode.ChildNodes.Delete(DependencyIdx);
end;

procedure Tdm_ManifestVersionInfo.EnableTheming;
var
  DependentAssemblyNode: IXMLNode;
  DependencyNode: IXMLNode;
  AssemblyNode: IXMLNode;
  DescriptionIdx: Integer;
begin
  if FindComCtlNode(DependentAssemblyNode) then begin
    // Node already exists, so theming is already enabled
    Exit; //==>
  end;

  AssemblyNode := ProjDoc.DocumentElement;

  // we must insert the dependency element before the description element, otherwise the application won't start
  DescriptionIdx := AssemblyNode.ChildNodes.IndexOf('description');

  DependencyNode := AssemblyNode.AddChild('dependency', DescriptionIdx);
  DependentAssemblyNode := DependencyNode.AddChild('dependentAssembly');
  DependentAssemblyNode.Attributes['type'] := 'win32';
  DependentAssemblyNode.Attributes['name'] := 'Microsoft.Windows.Common-Controls';
  DependentAssemblyNode.Attributes['version'] := '6.0.0.0';
  DependentAssemblyNode.Attributes['publicKeyToken'] := '6595b64144ccf1df';
  DependentAssemblyNode.Attributes['language'] := '*';
  DependentAssemblyNode.Attributes['processorArchitecture'] := '*';
end;

procedure Tdm_ManifestVersionInfo.InitVersionNodes;
var
  AssemblyNode: IXMLNode;
begin
  AssemblyNode := ProjDoc.DocumentElement;

  FAssemblyIdentityNode := AssemblyNode.ChildNodes['assemblyIdentity'];
  FDescriptionNode := AssemblyNode.ChildNodes['description'];
end;

function Tdm_ManifestVersionInfo.VerInfoFilename: string;
begin
  Result := FOutputFilename;
end;

procedure Tdm_ManifestVersionInfo.ReadFromFile(_VerInfo: TVersionInfo);
var
  Version: string;
  Major: string;
  Minor: string;
  Release: string;
  Build: string;
begin
  raise Exception.Create(_('Reading version info from Manifest files is not supported.'));

  _VerInfo.Source := VerInfoFilename;
  _VerInfo.InternalName := Var2Str(FAssemblyIdentityNode.Attributes['name'], '');
  Version := Var2Str(FAssemblyIdentityNode.Attributes['version'], '');
  _VerInfo.FileVersion := Version;
  _VerInfo.FileDescription := FDescriptionNode.Text;
  Major := ExtractStr(Version, '.');
  Minor := ExtractStr(Version, '.');
  Release := ExtractStr(Version, '.');
  Build := ExtractStr(Version, '.');
  _VerInfo.MajorVer := StrToIntDef(Major, 0);
  _VerInfo.MinorVer := StrToIntDef(Minor, 0);
  _VerInfo.Release := StrToIntDef(Release, 0);
  _VerInfo.Build := StrToIntDef(Build, 0);
end;

procedure Tdm_ManifestVersionInfo.WriteToFile(_VerInfo: TVersionInfo);
begin
  if _VerInfo.InternalName = '' then
    raise Exception.Create(_('InternalName must not be empty because assemblyIdentity.name requires a value'));
  if _VerInfo.FileVersion = '' then
    raise Exception.Create(_('FileVersion must not be empty because assemblyIdentity.version requires a value'));
  FAssemblyIdentityNode.Attributes['name'] := _VerInfo.InternalName;
  FAssemblyIdentityNode.Attributes['version'] := _VerInfo.FileVersion;
  FDescriptionNode.Text := _VerInfo.FileDescription;
  ProjDoc.SaveToFile(FOutputFilename);
end;

// standard TInterfacedObject implementation of IInterface

function Tdm_ManifestVersionInfo.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE
end;

function Tdm_ManifestVersionInfo._AddRef: Integer;
begin
  Result := InterlockedIncrement(FRefCount);
end;

function Tdm_ManifestVersionInfo._Release: Integer;
begin
  Result := InterlockedDecrement(FRefCount);
  if Result = 0 then
    Destroy;
end;

end.

