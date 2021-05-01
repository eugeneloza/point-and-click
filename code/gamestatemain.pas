unit GameStateMain;

interface

uses
  Classes,
  CastleUIState, CastleComponentSerialize, CastleUIControls, CastleControls,
  CastleKeysMouse, CastleImages, CastleVectors, CastleScene, CastleViewport;

type
  { Our character}
  THero = class(TComponent)
  private const
    HeroSpeed = 800; {pixels per second}
  public
    FacingRight: Boolean;
    { Model/sprite of the hero }
    Scene: TCastleScene;
    { Where the hero is going now }
    Destination: TVector3;
    { Teleport hero to coordinates in World (relative to Background) }
    procedure SetOrigin(const AOrigin: TVector3);
    { Get hero coordinates in World (relative to background) }
    function GetOrigin: TVector3;
    procedure Update(const SecondsPassed: Single);
  end;

type
  { Main state, where most of the application logic takes place. }
  TStateMain = class(TUIState)
  private
    { Components designed using CGE editor, loaded from gamestatemain.castle-user-interface. }
    LabelFps: TCastleLabel;
    Background: TCastleScene;
    { An image that contains "map" of possible player's movements and corresponding Z coordinates }
    MoveMap: TGrayscaleImage;
    Hero: THero;
  public
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
  end;

var
  StateMain: TStateMain;

implementation

uses
  SysUtils,
  CastleLog;

{ THero ----------------------------------------------------------------- }

procedure THero.SetOrigin(const AOrigin: TVector3);
var
  HeroScale: Single;
begin
  { We shift by Scene.BoundingBox.Size.Y / 2 because we want coordinates of
    the player's origin, not center. We could/should have set up that in the model. }
  Scene.Translation := AOrigin + Vector3(0, Scene.BoundingBox.Size.Y / 2, 0);
  { The larger Z coordinate of the hero - the further he is away
    And thus the smaller he should look }
  HeroScale := Scene.Translation.Z / 255;
  if FacingRight then
    Scene.Scale := Vector3(HeroScale, HeroScale, HeroScale)
  else
    Scene.Scale := Vector3(-HeroScale, HeroScale, HeroScale);
end;

function THero.GetOrigin: TVector3;
begin
  Result := Scene.Translation - Vector3(0, Scene.BoundingBox.Size.Y / 2, 0);
end;

procedure THero.Update(const SecondsPassed: Single);
var
  Shift: Single;
  HeroMovement: TVector3;
begin
  if (Destination - GetOrigin).Length > 0 then
  begin
    // How far can Player go this frame
    Shift := SecondsPassed * HeroSpeed * (Scene.Translation.z / 255);
    // If destination is not reached yet
    if Shift < (Destination - GetOrigin).Length then
    begin
      // Movement vector
      HeroMovement := (Destination - GetOrigin).Normalize * Shift;
      // Teleport player to new location
      SetOrigin(GetOrigin + HeroMovement);

      // Determine if the player should look right or left now based on movement
      if Destination.x < GetOrigin.x then
        FacingRight := false
      else
        FacingRight := true;
    end else
      SetOrigin(Destination);
  end;
end;

{ TStateMain ----------------------------------------------------------------- }

procedure TStateMain.Start;
var
  UiOwner: TComponent;
begin
  inherited;

  { Load designed user interface }
  InsertUserInterface('castle-data:/gamestatemain.castle-user-interface', FreeAtStop, UiOwner);
  MoveMap := LoadImage('castle-data:/pompeii-ruins-1430653165OsX_CC0_by_Svetlana_Tikhonova_[zmap].png', [TGrayscaleImage]) as TGrayscaleImage;
  Background := UiOwner.FindRequiredComponent('Background') as TCastleScene;

  Hero := THero.Create(FreeAtStop);
  Hero.Scene := UiOwner.FindRequiredComponent('Hero') as TCastleScene;
  Hero.Destination := Hero.GetOrigin;

  { Find components, by name, that we need to access from code }
  LabelFps := UiOwner.FindRequiredComponent('LabelFps') as TCastleLabel;
end;

procedure TStateMain.Stop;
begin
  FreeAndNil(MoveMap);
  inherited;
end;

procedure TStateMain.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  LabelFps.Caption := 'FPS: ' + Container.Fps.ToString;
  Hero.Update(SecondsPassed);
end;

function TStateMain.Press(const Event: TInputPressRelease): Boolean;
var
  MoveMapResult: Integer;

  { Convert Click coordinates to pixels in MoveMap }
  function ClickToMap: TVector2Integer;
  var
    V: TVector2;
  begin
    V := Container.MousePosition / Self.UIScale;
    Result := Vector2Integer(Round(V.X), Round(V.Y));
  end;

begin
  Result := inherited;
  if Result then Exit; // allow the ancestor to handle keys

  if Event.IsMouseButton(buttonLeft) then
  begin
    // Check if MoveMap has this pixel - we encode "z" coordinate of the player as this pixel color
    MoveMapResult := -1;
    if (ClickToMap.X >= 0) and (ClickToMap.X < MoveMap.Width) and
       (ClickToMap.Y >= 0) and (ClickToMap.Y < MoveMap.Height) then
         MoveMapResult := MoveMap.PixelPtr(ClickToMap.X, ClickToMap.Y)^;

    // If move is allowed
    if MoveMapResult > 5 then
      Hero.Destination := Vector3(Container.MousePosition / Self.UIScale, MoveMapResult) - Background.Translation;

    Exit(true);
  end;
end;

end.
