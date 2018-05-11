IMPORT SALT_Profile;
EXPORT Str30Type := #IF (SALT_Profile.UnicodeCfg.UseUnicode)
  UNICODE30
#ELSE
  STRING30
#END
;
