/**
 * Returns the number of words that the string contains.  Words are separated by one or more separator strings. No 
 * spaces are stripped from either string before matching.
 * 
 * @param s       The string being searched in.
 * @param sep     The string used to separate words
 */
IMPORT STD;
IMPORT SALT_Profile;
EXPORT UNSIGNED4 WordCount(SALT_Profile.StrType s, STRING1 sep=' ') := 
#IF (SALT_Profile.UnicodeCfg.UseUnicode)
			unicodelib.UnicodeLocaleWordCount(s, UnicodeCfg.LocaleName);
#ELSE
			STD.Str.CountWords( s, sep);
#END
;
 

