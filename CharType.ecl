IMPORT SALT_Profile;
EXPORT CharType := #IF (SALT_Profile.UnicodeCfg.UseUnicode)
  UNICODE1
#ELSE
  STRING1
#END
;
