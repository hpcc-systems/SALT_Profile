IMPORT SALT_Profile;
EXPORT StrType := #IF(SALT_Profile.UnicodeCfg.UseUnicode)
  UNICODE
#ELSE
  STRING
#END
;
