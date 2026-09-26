unit uWilFile;

interface

uses
  Classes, SysUtils, WIL, DWinCtl;

var
  g_ClientImages : array[0..142] of TWMImages;
  g_DWinMan: TDWinManager;

  g_WBagItem: TWMImages;
  g_WMonImg: TWMImages;
  g_WMon2Img: TWMImages;
  g_WMon3Img: TWMImages;
  g_WMon4Img: TWMImages;
  g_WMon5Img: TWMImages;
  g_WMon6Img: TWMImages;
  g_WMon7Img: TWMImages;
  g_WMon8Img: TWMImages;
  g_WMon9Img: TWMImages;
  g_WMon10Img: TWMImages;
  g_WMon11Img: TWMImages;
  g_WMon12Img: TWMImages;
  g_WMon13Img: TWMImages;
  g_WMon14Img: TWMImages;
  g_WMon15Img: TWMImages;
  g_WMon16Img: TWMImages;
  g_WMon17Img: TWMImages;
  g_WMon18Img: TWMImages;
  g_WMon19Img: TWMImages;
  g_WMon20Img: TWMImages;
  g_WMon21Img: TWMImages;
  g_WMon22Img: TWMImages;
  g_WMon23Img: TWMImages;
  g_WMon24Img: TWMImages;
  g_WMon25Img: TWMImages;
  g_WDragonImg: TWMImages;

//===============Mir3==============
  g_MapImageList: array[0..69] of TWMImages;
  g_WInterface1c: TWMImages;
  g_WGameInter: TWMImages;
  g_WGameInter1: TWMImages;
  g_WProgUse: TWMImages;
  g_WM_HumImg: TWMImages;
  g_WM_Hair: TWMImages;
  g_WM_Weapon: array[0..4] of TWMImages;
  g_WM_WeaponEx: array[0..1] of TWMImages;
  g_WWM_HumImg: TWMImages;
  g_WWM_Hair: TWMImages;
  g_WWM_Weapon: array[0..4] of TWMImages;
  g_WWM_WeaponEx: array[0..1] of TWMImages;

  g_WNpcImg: TWMImages;
  g_WMMap: TWMImages;
  g_WFMMap: TWMImages;
  g_WInventory: TWMImages;
  g_WStoreItem: TWMImages;
  g_WEquip: TWMImages;
  g_WGround: TWMImages;

  g_WMIcon: TWMImages;
  g_WMon: array[0..19] of TWMImages;
  g_WMonS: array[0..19] of TWMImages;

  g_WMonMagic: TWMImages;
  g_WMonMagicEx: array[0..3] of TWMImages;

  g_WMagic: TWMImages;
  g_WMagicEx: array[0..1] of TWMImages;

procedure LoadWMImagesLib(AOwner: TComponent);
procedure InitWMImagesLib;
procedure RefClientImages();
procedure UnLoadWMImagesLib();

implementation

procedure LoadWMImagesLib(AOwner: TComponent);
var
  I: Integer;
begin
  g_WBagItem := CreateWMImages(t_wmM2Def);
  g_WMonImg := CreateWMImages(t_wmM2Def);
  g_WMon2Img := CreateWMImages(t_wmM2Def);
  g_WMon3Img := CreateWMImages(t_wmM2Def);
  g_WMon4Img := CreateWMImages(t_wmM2Def);
  g_WMon5Img := CreateWMImages(t_wmM2Def);
  g_WMon6Img := CreateWMImages(t_wmM2Def);
  g_WMon7Img := CreateWMImages(t_wmM2Def);
  g_WMon8Img := CreateWMImages(t_wmM2Def);
  g_WMon9Img := CreateWMImages(t_wmM2Def);
  g_WMon10Img := CreateWMImages(t_wmM2Def);
  g_WMon11Img := CreateWMImages(t_wmM2Def);
  g_WMon12Img := CreateWMImages(t_wmM2Def);
  g_WMon13Img := CreateWMImages(t_wmM2Def);
  g_WMon14Img := CreateWMImages(t_wmM2Def);
  g_WMon15Img := CreateWMImages(t_wmM2Def);
  g_WMon16Img := CreateWMImages(t_wmM2Def);
  g_WMon17Img := CreateWMImages(t_wmM2Def);
  g_WMon18Img := CreateWMImages(t_wmM2Def);
  g_WMon19Img := CreateWMImages(t_wmM2Def);
  g_WMon20Img := CreateWMImages(t_wmM2Def);
  g_WMon21Img := CreateWMImages(t_wmM2Def);
  g_WMon22Img := CreateWMImages(t_wmM2Def);
  g_WMon23Img := CreateWMImages(t_wmM2Def);
  g_WMon24Img := CreateWMImages(t_wmM2Def);
  g_WMon25Img := CreateWMImages(t_wmM2Def);
  g_WDragonImg := CreateWMImages(t_wmM2Def);

//===============Mir3==============
  for I := Low(g_MapImageList) to High(g_MapImageList) do begin
    g_MapImageList[I] := CreateWMImages(t_wmMyImage);
  end;

  g_WInterface1c := CreateWMImages(t_wmMyImage);
  g_WGameInter := CreateWMImages(t_wmMyImage);
  g_WGameInter1 := CreateWMImages(t_wmMyImage);
  g_WProgUse := CreateWMImages(t_wmMyImage);

  g_WM_HumImg := CreateWMImages(t_wmMyImage);
  g_WM_Hair := CreateWMImages(t_wmMyImage);
  for I := Low(g_WM_Weapon) to High(g_WM_Weapon) do begin
    g_WM_Weapon[I] := CreateWMImages(t_wmMyImage);
  end;
  for I := Low(g_WM_WeaponEx) to High(g_WM_WeaponEx) do begin
    g_WM_WeaponEx[I] := CreateWMImages(t_wmMyImage);
  end;
  g_WWM_HumImg := CreateWMImages(t_wmMyImage);
  g_WWM_Hair := CreateWMImages(t_wmMyImage);
  for I := Low(g_WWM_Weapon) to High(g_WWM_Weapon) do begin
    g_WWM_Weapon[I] := CreateWMImages(t_wmMyImage);
  end;
  for I := Low(g_WWM_WeaponEx) to High(g_WWM_WeaponEx) do begin
    g_WWM_WeaponEx[I] := CreateWMImages(t_wmMyImage);
  end;

  g_WNpcImg := CreateWMImages(t_wmMyImage);
  g_WMMap := CreateWMImages(t_wmMyImage);
  g_WFMMap := CreateWMImages(t_wmMyImage);
  g_WInventory := CreateWMImages(t_wmMyImage);
  g_WStoreItem := CreateWMImages(t_wmMyImage);
  g_WEquip := CreateWMImages(t_wmMyImage);
  g_WGround := CreateWMImages(t_wmMyImage);

  g_WMIcon := CreateWMImages(t_wmMyImage);
  for I := Low(g_WMon) to High(g_WMon) do begin
    g_WMon[I] := CreateWMImages(t_wmMyImage);
  end;
  for I := Low(g_WMonS) to High(g_WMonS) do begin
    g_WMonS[I] := CreateWMImages(t_wmMyImage);
  end;

  g_WMonMagic := CreateWMImages(t_wmMyImage);
  for I := Low(g_WMonMagicEx) to High(g_WMonMagicEx) do begin
    g_WMonMagicEx[I] := CreateWMImages(t_wmMyImage);
  end;

  g_WMagic := CreateWMImages(t_wmMyImage);
  for I := Low(g_WMagicEx) to High(g_WMagicEx) do begin
    g_WMagicEx[I] := CreateWMImages(t_wmMyImage);
  end;
  RefClientImages();
end;

procedure InitWMImagesLib;
//  procedure InitializeImage(var AWMImages: TWMImages);
//  var
//    sFileName: string;
//    vLibType: TLibType;
//  begin
//    if (not AWMImages.Initialize()) and (AWMImages.FileName <> '') then begin
//      sFileName := ChangeFileExt(AWMImages.FileName, '.wil');
//      vLibType := AWMImages.LibType;
//      AWMImages.Finalize;
//      AWMImages.Free;
//      AWMImages := CreateWMImages(t_wmM3Def);
//      AWMImages.FileName := sFileName;
//      AWMImages.LibType := vLibType;
//      AWMImages.Initialize();
//    end;
//  end;
   procedure InitializeImage(var AWMImages: TWMImages);
   var
     sFileName, sPassword: string;
     vLibType: TLibType;
   begin
     if (not AWMImages.Initialize()) and (AWMImages.FileName <> '') and (AWMImages.WILType in [t_wmMyImage]) then
     begin
       sFileName := ChangeFileExt(AWMImages.FileName, '.wil');
       //DebugOutStr(sFileName);
       vLibType := AWMImages.LibType;
       sPassword := AWMImages.Password;
       AWMImages.Finalize;
       AWMImages.Free;
       AWMImages := CreateWMImages(t_wmM3Def);
       AWMImages.FileName := sFileName;
       AWMImages.LibType := vLibType;
       AWMImages.Password := sPassword;
       AWMImages.Initialize();
     end;
   end;
var
  I: integer;
begin
  g_MapImageList[0].FileName := 'Data\tilesc.Lib';
  g_MapImageList[1].FileName := 'Data\tiles30c.Lib';
  g_MapImageList[2].FileName := 'Data\Tiles5c.Lib';
  g_MapImageList[3].FileName := 'Data\smtilesc.Lib';	
  g_MapImageList[4].FileName := 'Data\housesc.Lib';	
  g_MapImageList[5].FileName := 'Data\cliffsc.Lib';
  g_MapImageList[6].FileName := 'Data\dungeonsc.Lib';
  g_MapImageList[7].FileName := 'Data\innersc.Lib';
  g_MapImageList[8].FileName := 'Data\furnituresc.Lib';
  g_MapImageList[9].FileName := 'Data\wallsc.Lib';	
  g_MapImageList[10].FileName := 'Data\smobjectsc.Lib';
  g_MapImageList[11].FileName := 'Data\animationsc.Lib';
  g_MapImageList[12].FileName := 'Data\object1c.Lib';
  g_MapImageList[13].FileName := 'Data\object2c.Lib';
  g_MapImageList[14].FileName := 'Data\Wood\tilesc.Lib';
  g_MapImageList[15].FileName := 'Data\Wood\tiles30c.Lib';
  g_MapImageList[16].FileName := 'Data\Wood\Tiles5c.Lib';
  g_MapImageList[17].FileName := 'Data\Wood\smtilesc.Lib';
  g_MapImageList[18].FileName := 'Data\Wood\housesc.Lib';
  g_MapImageList[19].FileName := 'Data\Wood\cliffsc.Lib';
  g_MapImageList[20].FileName := 'Data\Wood\dungeonsc.Lib';
  g_MapImageList[21].FileName := 'Data\Wood\innersc.Lib';
  g_MapImageList[22].FileName := 'Data\Wood\furnituresc.Lib';
  g_MapImageList[23].FileName := 'Data\Wood\wallsc.Lib';
  g_MapImageList[24].FileName := 'Data\Wood\smobjectsc.Lib';
  g_MapImageList[25].FileName := 'Data\Wood\animationsc.Lib';
  g_MapImageList[26].FileName := 'Data\Wood\object1c.Lib';
  g_MapImageList[27].FileName := 'Data\Wood\object2c.Lib';
  g_MapImageList[28].FileName := 'Data\Sand\tilesc.Lib';
  g_MapImageList[29].FileName := 'Data\Sand\tiles30c.Lib';
  g_MapImageList[30].FileName := 'Data\Sand\Tiles5c.Lib';
  g_MapImageList[31].FileName := 'Data\Sand\smtilesc.Lib';
  g_MapImageList[32].FileName := 'Data\Sand\housesc.Lib';
  g_MapImageList[33].FileName := 'Data\Sand\cliffsc.Lib';
  g_MapImageList[34].FileName := 'Data\Sand\dungeonsc.Lib';
  g_MapImageList[35].FileName := 'Data\Sand\innersc.Lib';
  g_MapImageList[36].FileName := 'Data\Sand\furnituresc.Lib';
  g_MapImageList[37].FileName := 'Data\Sand\wallsc.Lib';
  g_MapImageList[38].FileName := 'Data\Sand\smobjectsc.Lib';
  g_MapImageList[39].FileName := 'Data\Sand\animationsc.Lib';
  g_MapImageList[40].FileName := 'Data\Sand\object1c.Lib';
  g_MapImageList[41].FileName := 'Data\Sand\object2c.Lib';
  g_MapImageList[42].FileName := 'Data\Snow\tilesc.Lib';
  g_MapImageList[43].FileName := 'Data\Snow\tiles30c.Lib';
  g_MapImageList[44].FileName := 'Data\Snow\Tiles5c.Lib';
  g_MapImageList[45].FileName := 'Data\Snow\smtilesc.Lib';
  g_MapImageList[46].FileName := 'Data\Snow\housesc.Lib';
  g_MapImageList[47].FileName := 'Data\Snow\cliffsc.Lib';
  g_MapImageList[48].FileName := 'Data\Snow\dungeonsc.Lib';
  g_MapImageList[49].FileName := 'Data\Snow\innersc.Lib';
  g_MapImageList[50].FileName := 'Data\Snow\furnituresc.Lib';
  g_MapImageList[51].FileName := 'Data\Snow\wallsc.Lib';
  g_MapImageList[52].FileName := 'Data\Snow\smobjectsc.Lib';
  g_MapImageList[53].FileName := 'Data\Snow\animationsc.Lib';
  g_MapImageList[54].FileName := 'Data\Snow\object1c.Lib';
  g_MapImageList[55].FileName := 'Data\Snow\object2c.Lib';
  g_MapImageList[56].FileName := 'Data\Forest\tilesc.Lib';
  g_MapImageList[57].FileName := 'Data\Forest\tiles30c.Lib';
  g_MapImageList[58].FileName := 'Data\Forest\Tiles5c.Lib';
  g_MapImageList[59].FileName := 'Data\Forest\smtilesc.Lib';
  g_MapImageList[60].FileName := 'Data\Forest\housesc.Lib';
  g_MapImageList[61].FileName := 'Data\Forest\cliffsc.Lib';
  g_MapImageList[62].FileName := 'Data\Forest\dungeonsc.Lib';
  g_MapImageList[63].FileName := 'Data\Forest\innersc.Lib';
  g_MapImageList[64].FileName := 'Data\Forest\furnituresc.Lib';
  g_MapImageList[65].FileName := 'Data\Forest\wallsc.Lib';
  g_MapImageList[66].FileName := 'Data\Forest\smobjectsc.Lib';
  g_MapImageList[67].FileName := 'Data\Forest\animationsc.Lib';
  g_MapImageList[68].FileName := 'Data\Forest\object1c.Lib';
  g_MapImageList[69].FileName := 'Data\Forest\object2c.Lib';
  for I := Low(g_MapImageList) to High(g_MapImageList) do begin
    if FileExists(g_MapImageList[I].FileName) then begin
      g_MapImageList[I].LibType := ltUseCache;
      InitializeImage(g_MapImageList[I]);
    end else begin
      g_MapImageList[I].LibType := ltLoadMemory;
      InitializeImage(g_MapImageList[I]);
    end;
  end;

  g_WInterface1c.FileName := 'Data\Interface1c.Lib';
  g_WInterface1c.LibType := ltUseCache;
  InitializeImage(g_WInterface1c);
  g_WGameInter.FileName := 'Data\GameInter.Lib';;
  g_WGameInter.LibType := ltUseCache;
  InitializeImage(g_WGameInter);
  g_WGameInter1.FileName := 'Data\GameInter1.Lib';;
  g_WGameInter1.LibType := ltUseCache;
  InitializeImage(g_WGameInter1);
  g_WProgUse.FileName := 'Data\ProgUse.Lib';
  g_WProgUse.LibType := ltUseCache;
  InitializeImage(g_WProgUse);
  g_WM_HumImg.FileName := 'Data\M-Hum.Lib';
  g_WM_HumImg.LibType := ltUseCache;
  InitializeImage(g_WM_HumImg);
  g_WM_Hair.FileName := 'Data\M-Hair.Lib';
  g_WM_Hair.LibType := ltUseCache;
  InitializeImage(g_WM_Hair);
  for I := Low(g_WM_Weapon) to High(g_WM_Weapon) do begin
    g_WM_Weapon[I].FileName := Format('Data\M-Weapon%d.Lib', [I+1]);
    if FileExists(g_WM_Weapon[I].FileName) then begin
      g_WM_Weapon[I].LibType := ltUseCache;
      InitializeImage(g_WM_Weapon[I]);
    end else begin
      g_WM_Weapon[I].LibType := ltUseCache;
      InitializeImage(g_WM_Weapon[I]);
    end;
  end;
  for I := Low(g_WM_WeaponEx) to High(g_WM_WeaponEx) do begin
    g_WM_WeaponEx[I].FileName := Format('Data\M-Weapon%d.Lib', [I+10]);
    if FileExists(g_WM_WeaponEx[I].FileName) then begin
      g_WM_WeaponEx[I].LibType := ltUseCache;
      InitializeImage(g_WM_WeaponEx[I]);
    end else begin
      g_WM_WeaponEx[I].LibType := ltUseCache;
      InitializeImage(g_WM_WeaponEx[I]);
    end;
  end;
  g_WWM_HumImg.FileName := 'Data\WM-Hum.Lib';
  g_WWM_HumImg.LibType := ltUseCache;
  InitializeImage(g_WWM_HumImg);
  g_WWM_Hair.FileName := 'Data\M-Hair.Lib';
  g_WWM_Hair.LibType := ltUseCache;
  InitializeImage(g_WWM_Hair);
  for I := Low(g_WWM_Weapon) to High(g_WWM_Weapon) do begin
    g_WWM_Weapon[I].FileName := Format('Data\M-Weapon%d.Lib', [I+1]);
    if FileExists(g_WWM_Weapon[I].FileName) then begin
      g_WWM_Weapon[I].LibType := ltUseCache;
      InitializeImage(g_WWM_Weapon[I]);
    end else begin
      g_WWM_Weapon[I].LibType := ltUseCache;
      InitializeImage(g_WWM_Weapon[I]);
    end;
  end;
  for I := Low(g_WWM_WeaponEx) to High(g_WWM_WeaponEx) do begin
    g_WWM_WeaponEx[I].FileName := Format('Data\M-Weapon%d.Lib', [I+10]);
    if FileExists(g_WWM_WeaponEx[I].FileName) then begin
      g_WWM_WeaponEx[I].LibType := ltUseCache;
      InitializeImage(g_WWM_WeaponEx[I]);
    end else begin
      g_WWM_WeaponEx[I].LibType := ltUseCache;
      InitializeImage(g_WWM_WeaponEx[I]);
    end;
  end;
  g_WNpcImg.FileName := 'Data\Npc.Lib';
  g_WNpcImg.LibType := ltUseCache;
  InitializeImage(g_WNpcImg);
  g_WMMap.FileName := 'Data\Mmap.Lib';
  g_WMMap.LibType := ltUseCache;
  InitializeImage(g_WMMap);
  g_WFMMap.FileName := 'Data\Fmmap.Lib';
  g_WFMMap.LibType := ltUseCache;
  InitializeImage(g_WFMMap);

  g_WInventory.FileName := 'Data\Inventory.Lib';
  g_WInventory.LibType := ltUseCache;
  InitializeImage(g_WInventory);
  g_WStoreItem.FileName := 'Data\StoreItem.Lib';
  g_WStoreItem.LibType := ltUseCache;
  InitializeImage(g_WStoreItem);
  g_WEquip.FileName := 'Data\Equip.Lib';
  g_WEquip.LibType := ltUseCache;
  InitializeImage(g_WEquip);
  g_WGround.FileName := 'Data\Ground.Lib';
  g_WGround.LibType := ltUseCache;
  InitializeImage(g_WGround);

  g_WMIcon.FileName := 'Data\MIcon.Lib';
  g_WMIcon.LibType := ltUseCache;
  InitializeImage(g_WMIcon);
  for I := Low(g_WMon) to High(g_WMon) do begin
    g_WMon[I].FileName := Format('Data\Mon-%d.Lib', [I+1]);
    if FileExists(g_WMon[I].FileName) then begin
      g_WMon[I].LibType := ltUseCache;
      InitializeImage(g_WMon[I]);
    end else begin
      g_WMon[I].LibType := ltUseCache;
      InitializeImage(g_WMon[I]);
    end;
  end;
  for I := Low(g_WMonS) to High(g_WMonS) do begin
    g_WMonS[I].FileName := Format('Data\MonS-%d.Lib', [I+1]);
    if FileExists(g_WMonS[I].FileName) then begin
      g_WMonS[I].LibType := ltUseCache;
      InitializeImage(g_WMonS[I]);
    end else begin
      g_WMonS[I].LibType := ltUseCache;
      InitializeImage(g_WMonS[I]);
    end;
  end;

  g_WMonMagic.FileName := 'Data\MonMagic.Lib';
  g_WMonMagic.LibType := ltUseCache;
  InitializeImage(g_WMonMagic);
  for I := Low(g_WMonMagicEx) to High(g_WMonMagicEx) do begin
    if I <> 0 then  g_WMonMagicEx[I].FileName := Format('Data\MonMagicEx%d.Lib', [I+1])
    else g_WMonMagicEx[I].FileName := 'Data\MonMagicEx.Lib';
    if FileExists(g_WMonMagicEx[I].FileName) then begin
      g_WMonMagicEx[I].LibType := ltUseCache;
      InitializeImage(g_WMonMagicEx[I]);
    end else begin
      g_WMonMagicEx[I].LibType := ltUseCache;
      InitializeImage(g_WMonMagicEx[I]);
    end;
  end;

  g_WMagic.FileName := 'Data\Magic.Lib';
  g_WMagic.LibType := ltUseCache;
  InitializeImage(g_WMagic);
  for I := Low(g_WMagicEx) to High(g_WMagicEx) do begin
    if I <> 0 then  g_WMagicEx[I].FileName := Format('Data\MagicEx%d.Lib', [I+1])
    else g_WMagicEx[I].FileName := 'Data\MagicEx.Lib';
    if FileExists(g_WMagicEx[I].FileName) then begin
      g_WMagicEx[I].LibType := ltUseCache;
      InitializeImage(g_WMagicEx[I]);
    end else begin
      g_WMagicEx[I].LibType := ltUseCache;
      InitializeImage(g_WMagicEx[I]);
    end;
  end;

  g_WBagItem.FileName := 'Data\Items.wil';
  g_WMonImg.FileName := 'Data\Mon1.wil';
  g_WMon2Img.FileName := 'Data\Mon2.wil';
  g_WMon3Img.FileName := 'Data\Mon3.wil';
  g_WMon4Img.FileName := 'Data\Mon4.wil';
  g_WMon5Img.FileName := 'Data\Mon5.wil';
  g_WMon6Img.FileName := 'Data\Mon6.wil';
  g_WMon7Img.FileName := 'Data\Mon7.wil';
  g_WMon8Img.FileName := 'Data\Mon8.wil';
  g_WMon9Img.FileName := 'Data\Mon9.wil';
  g_WMon10Img.FileName := 'Data\Mon10.wil';
  g_WMon11Img.FileName := 'Data\Mon11.wil';
  g_WMon12Img.FileName := 'Data\Mon12.wil';
  g_WMon13Img.FileName := 'Data\Mon13.wil';
  g_WMon14Img.FileName := 'Data\Mon14.wil';
  g_WMon15Img.FileName := 'Data\Mon15.wil';
  g_WMon16Img.FileName := 'Data\Mon16.wil';
  g_WMon17Img.FileName := 'Data\Mon17.wil';
  g_WMon18Img.FileName := 'Data\Mon18.wil';
  g_WMon19Img.FileName := 'Data\Mon19.wil';
  g_WMon20Img.FileName := 'Data\Mon20.wil';
  g_WMon21Img.FileName := 'Data\Mon21.wil';
  g_WMon22Img.FileName := 'Data\Mon22.wil';
  g_WMon23Img.FileName := 'Data\Mon23.wil';
  g_WMon24Img.FileName := 'Data\Mon24.wil';
  g_WMon25Img.FileName := 'Data\Mon25.wil';
  g_WDragonImg.FileName := 'Data\Dragon.wil';

  g_WBagItem.LibType := ltUseCache;
  g_WMonImg.LibType := ltUseCache;
  g_WMon2Img.LibType := ltUseCache;
  g_WMon3Img.LibType := ltUseCache;
  g_WMon4Img.LibType := ltUseCache;
  g_WMon5Img.LibType := ltUseCache;
  g_WMon6Img.LibType := ltUseCache;
  g_WMon7Img.LibType := ltUseCache;
  g_WMon8Img.LibType := ltUseCache;
  g_WMon9Img.LibType := ltUseCache;
  g_WMon10Img.LibType := ltUseCache;
  g_WMon11Img.LibType := ltUseCache;
  g_WMon12Img.LibType := ltUseCache;
  g_WMon13Img.LibType := ltUseCache;
  g_WMon14Img.LibType := ltUseCache;
  g_WMon15Img.LibType := ltUseCache;
  g_WMon16Img.LibType := ltUseCache;
  g_WMon17Img.LibType := ltUseCache;
  g_WMon18Img.LibType := ltUseCache;
  g_WMon19Img.LibType := ltUseCache;
  g_WMon20Img.LibType := ltUseCache;
  g_WMon21Img.LibType := ltUseCache;
  g_WMon22Img.LibType := ltUseCache;
  g_WMon23Img.LibType := ltUseCache;
  g_WMon24Img.LibType := ltUseCache;
  g_WMon25Img.LibType := ltUseCache;
  g_WDragonImg.LibType := ltUseCache;

  InitializeImage(g_WBagItem);
  InitializeImage(g_WMonImg);
  InitializeImage(g_WMon2Img);
  InitializeImage(g_WMon3Img);
  InitializeImage(g_WMon4Img);
  InitializeImage(g_WMon5Img);
  InitializeImage(g_WMon6Img);
  InitializeImage(g_WMon7Img);
  InitializeImage(g_WMon8Img);
  InitializeImage(g_WMon9Img);
  InitializeImage(g_WMon10Img);
  InitializeImage(g_WMon11Img);
  InitializeImage(g_WMon12Img);
  InitializeImage(g_WMon13Img);
  InitializeImage(g_WMon14Img);
  InitializeImage(g_WMon15Img);
  InitializeImage(g_WMon16Img);
  InitializeImage(g_WMon17Img);
  InitializeImage(g_WMon18Img);
  InitializeImage(g_WMon19Img);
  InitializeImage(g_WMon20Img);
  InitializeImage(g_WMon21Img);
  InitializeImage(g_WMon22Img);
  InitializeImage(g_WMon23Img);
  InitializeImage(g_WMon24Img);
  InitializeImage(g_WMon25Img);
  InitializeImage(g_WDragonImg);
  RefClientImages();
end;

procedure RefClientImages();
var
  i: Integer;
begin
  for I := Low(g_ClientImages) to High(g_ClientImages) do begin
    g_ClientImages[I] := nil;
    case I of
      0..69: g_ClientImages[I] := g_MapImageList[I];
      70: g_ClientImages[I] := g_WInterface1c;
      71: g_ClientImages[I] := g_WGameInter;
      72: g_ClientImages[I] := g_WProgUse;
      73: g_ClientImages[I] := g_WGameInter1;

      74: g_ClientImages[I] := g_WM_HumImg;
      75: g_ClientImages[I] := g_WM_Hair;
      76..79: g_ClientImages[I] := g_WM_Weapon[I-76];
      80,81: g_ClientImages[I] := g_WM_WeaponEx[I-80];
      82: g_ClientImages[I] := g_WWM_HumImg;
      83: g_ClientImages[I] := g_WWM_Hair;
      84..87: g_ClientImages[I] := g_WWM_Weapon[I-84];
      88,89: g_ClientImages[I] := g_WWM_WeaponEx[I-88];

      90: g_ClientImages[I] := g_WNpcImg;
      91: g_ClientImages[I] := g_WMMap;
      92: g_ClientImages[I] := g_WFMMap;
      93: g_ClientImages[I] := g_WInventory;
      94: g_ClientImages[I] := g_WStoreItem;
      95: g_ClientImages[I] := g_WEquip;

      96: g_ClientImages[I] := g_WMIcon;
      97..116: g_ClientImages[I] := g_WMon[I-97];
      117..136: g_ClientImages[I] := g_WMonS[I-117];

      137: g_ClientImages[I] := g_WMonMagic;
      138..141: g_ClientImages[I] := g_WMonMagicEx[I-138];
      142: g_ClientImages[I] := g_WGround;
      143: g_ClientImages[I] := g_WMagic;
      144,145,146: g_ClientImages[I] := g_WMagicEx[I-144];
    end;
  end;
end;

procedure UnLoadWMImagesLib();
var
  i: Integer;
begin
  for I := Low(g_ClientImages) to High(g_ClientImages) do begin
    if g_ClientImages[i] <> nil then begin
      g_ClientImages[i].Finalize;
      g_ClientImages[i].Free;
      g_ClientImages[i] := nil;
    end;
  end;
end;

initialization
  begin
    FillChar(g_ClientImages, SizeOf(g_ClientImages), #0);
  end;

finalization
  begin
  end;

end.




