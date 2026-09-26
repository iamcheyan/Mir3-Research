unit MShare;

interface

uses
  Windows, WIL;


type
  TImagesStatus = (isNone, isReady);
  TWMFileType = (wtWil, wtWis, wtWiz);
  
  TImagesInfo = packed record
    szFileName:string[32];              //文件名称
    dwRecord:LongWord;                  //文件标识(服务器端TWMImages对象)
    wfFormat:TWILColorFormat;           //颜色格式
  end;

  TWMImages = packed record
    dwRecord:LongWord;                  //文件标识
    dwImages:LongWord;                  //资源编号
    dwTrans:LongWord;                   //资源大小
    isStatus:TImagesStatus;             //资源状态
    ftType:TWMFileType;                 //文件类型
    wtType:TWILType;                    //压缩类型(t_wmM2Def, t_wmM2wis, t_wmM2Zip)
  end;


implementation

end.
 