IMPORT SALT_Profile;
EXPORT MAC_Character_Counts := MODULE
  SHARED MaxExamples := 300;
  SHARED MaxChars := 256; // Change to allow more than 256 different characters in string
  SHARED MaxFixedLen := 100; // Maximum length allocated for a fix length string (longer than this will be variable length string)
  
  EXPORT Data_Layout := RECORD
    SALT_Profile.StrType Fld { MAXLENGTH(200000) };
    UNSIGNED2 FldNo;
   END;
	
  SHARED Length_Layout := RECORD
    UNSIGNED2 len;
    UNSIGNED  cnt;
    REAL pcnt;	
  END;
	
  SHARED Words_Layout := RECORD
    UNSIGNED2 words;
    UNSIGNED  cnt;
    REAL pcnt;	
  END;
	
  SHARED Character_Layout := RECORD
    SALT_Profile.CharType c;
    UNSIGNED cnt;
    REAL pcnt;	
  END;	
	
  SHARED Pattern_Layout := RECORD
    SALT_Profile.StrType data_pattern {MAXLENGTH(200000)};
    UNSIGNED cnt;
    REAL pcnt;
  END;
	
  SHARED Value_Layout := RECORD
    SALT_Profile.StrType val {maxlength(200000)};
    UNSIGNED cnt;
    REAL pcnt;
  END;
  
  EXPORT Field_Identification := RECORD
    UNSIGNED2 FldNo;
    SALT_Profile.StrType FieldName;
  END;
  
  EXPORT ResultLine_Layout := RECORD(Field_Identification)
    UNSIGNED                  Cardinality;
    SALT_Profile.Str30Type 			MinVal30;
    SALT_Profile.Str30Type 			MaxVal30;
    REAL8                     AsNumber_MinVal;
    REAL8                     AsNumber_MaxVal;
    REAL8                     AsNumber_Mean;
    REAL8                     AsNumber_Var;
    DATASET(Length_Layout)    Len {MAXCOUNT(MaxChars)} := DATASET([],Length_Layout);
    DATASET(Words_Layout)     Words {MAXCOUNT(MaxChars)} := DATASET([],Words_Layout);
    DATASET(Character_Layout) Characters {MAXCOUNT(MaxChars)} := DATASET([],Character_Layout);
    DATASET(Pattern_Layout)   Patterns {MAXCOUNT(MaxExamples)}:= DATASET([],Pattern_Layout);
    DATASET(Value_Layout)     Frequent_Terms {MAXCOUNT(MaxExamples)}:= DATASET([],Value_Layout);
  END;

  EXPORT EclRecord(DATASET(ResultLine_Layout) d, STRING RName='Record_Layout') := FUNCTION
    R := RECORD
      d.FldNo;
      d.FieldName;
      HasNeg := EXISTS(d.Characters(c='-'));
      HasDot := EXISTS(d.Characters(c='.'));
      NoNum := ~EXISTS(d.Characters(c IN ['0','1','2','3','4','5','6','7','8','9','.','-']));
      AllNum := ~EXISTS(d.Characters(NOT c IN ['0','1','2','3','4','5','6','7','8','9','e','E','.','-']));
      MaxLen := MAX(d.Len,len);
    END;
    t := TABLE(d,r);
    r1 := RECORD
      t.FldNo;
      SALT_Profile.StrType Txt;
    END;
    Len2Size(UNSIGNED2 c) := MAP ( c < 3 => 1, c < 5 => 2, c < 7 => 3, c < 9 => 4, c < 11 => 5, c < 14 => 6, c < 16 => 7, 8 );
    boiler := DATASET([{0,RName+' := RECORD'},{100000,'  END;'}],r1);
    r1 WriteEcl(t le) := TRANSFORM
      #IF (SALT_Profile.UnicodeCfg.UseUnicode)
        SELF.Txt := '  '+MAP( ~le.AllNum => 'UNICODE' + IF(le.MaxLen<MaxFixedLen,(SALT_Profile.StrType)le.MaxLen, ''),
      #ELSE
        SELF.Txt := '  '+MAP( ~le.AllNum => 'STRING' + IF(le.MaxLen<MaxFixedLen,(SALT_Profile.StrType)le.MaxLen, ''),
      #END
        le.HasDot => 'REAL' + IF(le.MaxLen<8,'4','8'),
        le.HasNeg => 'INTEGER' + Len2Size(le.MaxLen),
        'UNSIGNED'+Len2Size(le.MaxLen) ) + ' ' + le.FieldName +';';
      SELF := le;
    END;
    P := TABLE(SORT(PROJECT(t,WriteEcl(LEFT))+boiler,FldNo,FEW),{Txt});
    RETURN P;
  END; // EclRecord
	
  EXPORT FieldTypes(DATASET(ResultLine_Layout) d, REAL Recall = 99.9) := FUNCTION
    PruneOutliers(file,cnt_field) := FUNCTIONMACRO
      t := SORT(TABLE(file,{file,UNSIGNED RunningCount := 0}),-cnt_field);
      // Note - MY running count does NOT include MY value, this is deliberate - it makes the filter much easier
      i := ITERATE(t,TRANSFORM(RECORDOF(t),SELF.RunningCount := LEFT.RunningCount+LEFT.cnt_field,SELF := RIGHT));
      RETURN PROJECT(i(RunningCount <= SUM(i,cnt_field)*(Recall/100)),RECORDOF(file));
    ENDMACRO;
    
    SALT_Profile.StrType GetChars(DATASET(Character_Layout) gc) := FUNCTION
      T := TABLE(SORT(PruneOutliers(gc(),cnt),c),{ SALT_Profile.StrType s := c; });
      RETURN ROLLUP(t,TRUE,TRANSFORM(RECORDOF(T),SELF.S := LEFT.S+RIGHT.S))[1].s;
    END;
    
    SALT_Profile.StrType LenList(DATASET(Length_Layout) lens) := FUNCTION
      T := TABLE(PruneOutliers(lens,cnt),{ SALT_Profile.StrType s := ','+len; });
      s := ROLLUP(t,TRUE,TRANSFORM(RECORDOF(T),SELF.S := LEFT.S+RIGHT.S))[1].s[2..];
      RETURN ':LENGTHS('+s+')';
    END;
    
    SALT_Profile.StrType WordList(DATASET(Words_Layout) wds) := FUNCTION
      T := TABLE(PruneOutliers(wds,cnt),{ SALT_Profile.StrType s := ','+words; });
      s := ROLLUP(t,TRUE,TRANSFORM(RECORDOF(T),SELF.S := LEFT.S+RIGHT.S))[1].s[2..];
      RETURN ':WORDS('+s+')';
    END;

    R := RECORD
      d.FldNo;
      d.FieldName;
      SALT_Profile.StrType Allow := ':ALLOW('+GetChars(d.Characters)+')';
      SALT_Profile.StrType LTrim := IF ( EXISTS(d.patterns(data_pattern[1]=' ',TRIM(data_pattern[2..])<>'')),'',':LEFTTRIM');
      SALT_Profile.StrType Lens := LenList(d.len);
      SALT_Profile.StrType Words := WordList(d.words);
      SALT_Profile.StrType Spaces := ':SPACES( )';
    END;
    
    t := TABLE(d,r);
    r1 := RECORD
      t.FldNo;
      SALT_Profile.StrType Txt;
    END;
    boiler := DATASET([],r1);
    r1 WriteEcl(t le) := TRANSFORM
      SELF.Txt := 'FIELDTYPE:'+le.FieldName+le.Spaces+le.allow+le.ltrim+le.Lens+le.Words+':ONFAIL(CLEAN)';
      SELF := le;
    END;
    P := TABLE(SORT(PROJECT(t,WriteEcl(LEFT))+boiler,FldNo,FEW),{Txt});
    
    RETURN P;
  END; // FieldTypes

  EXPORT FN_Profile(DATASET(Data_Layout) TheData,DATASET(Field_Identification)TheFields) := FUNCTION
    IRecTot0 := RECORD
      TheData.FldNo;
      UNSIGNED Cnt := COUNT(GROUP);
      REAL8 AsNumber_MinVal := MIN(GROUP,(REAL8)TheData.Fld);
      REAL8 AsNumber_MaxVal := MAX(GROUP,(REAL8)TheData.Fld);
      REAL8 AsNumber_Mean := AVE(GROUP,(REAL8)TheData.Fld);
      REAL8 AsNumber_Var := VARIANCE(GROUP,(REAL8)TheData.Fld);
    END;
    FldInv0 := TABLE(TheData,IRecTot0,FldNo,FEW);
    TF0 := JOIN(TheFields,FldInv0,LEFT.FldNo=RIGHT.FLdNo);
    
    IRecTot := RECORD
      TheData.Fld;
      TheData.FldNo;
      UNSIGNED Cnt := COUNT(GROUP);
    END;
    FldInv1 := TABLE(TheData,IRecTot,FldNo,Fld,MERGE);
    
    glbl_field_cnts := RECORD
      FldInv1;
      UNSIGNED2 xx_l := length(trim((SALT_Profile.StrType)FldInv1.Fld));
      UNSIGNED2 xx_wc := SALT_Profile.WordCount((SALT_Profile.StrType)FldInv1.Fld);
    END;
    FldInv := TABLE( FldInv1, glbl_field_cnts );

    card_rec := RECORD
      FldInv.FldNo;
      UNSIGNED Cardinality := COUNT(GROUP);
      SALT_Profile.Str30Type MaxVal30 := MAX(GROUP,FldInv.Fld);
      SALT_Profile.Str30Type MinVal30 := MIN(GROUP,IF(FldInv.Fld='','ZZ--BOGUSVALUE--ZZ',FldInv.Fld));
    END;	
    Cardinalities := TABLE(FldInv,card_rec,FldNo,FEW);

    ResultLine_Layout NoteCard(TF0 Le,Cardinalities ri) := transform
      SELF := ri;
      SELF := le;
    END;
    With_Cards := JOIN(TF0,Cardinalities,LEFT.FldNo=RIGHT.FldNo,NoteCard(LEFT,RIGHT));

    // Produce highest 'MaxExamples' frequency for each fieldtype
    so := SORT(FldInv,FldNo,-Cnt,LOCAL);
    gci := RECORD
      so;
      UNSIGNED4 ctr := 0;
    END;
    gci iter1(gci le,gci ri) := TRANSFORM
      self.ctr := IF (le.fldno=ri.fldno,le.ctr+1,1);
      self := ri;
    END;	
    first_pass := ITERATE(SORT(DISTRIBUTE(ITERATE(TABLE(so,gci),iter1(LEFT,RIGHT),LOCAL)(Ctr<=MaxExamples),FldNo),FldNo,-Cnt,LOCAL),iter1(LEFT,RIGHT),LOCAL)(Ctr<=MaxExamples);

    ResultLine_Layout AddField1(With_Cards le,first_pass ri) := TRANSFORM
      SELF.Frequent_Terms := le.Frequent_Terms+ROW({ri.Fld,ri.Cnt,ROUND(ri.Cnt*10000/FldInv0[1].Cnt)/100},Value_layout);
      SELF := le;
    END;
    With_Frequent := DENORMALIZE(With_Cards,first_pass,LEFT.FldNo=RIGHT.FldNo,AddField1(LEFT,RIGHT));
    
    length_rec := RECORD
      FldInv.FldNo;
      UNSIGNED2 len := FldInv.xx_l;
      UNSIGNED  Cnt := SUM(group,FldInv.cnt);
    END;
    FieldLengths := SORT(TABLE(FldInv,length_rec,FldNo,xx_l,FEW),FldNo,-cnt);

    ResultLine_Layout AddField2(With_Frequent le,FieldLengths ri) := TRANSFORM
      SELF.Len := IF(COUNT(le.Len)<255,le.Len+ROW({ri.len,ri.Cnt,ROUND(ri.Cnt*10000/FldInv0[1].Cnt)/100},Length_layout),le.Len);
      SELF := le;
    END;
    With_Lens := DENORMALIZE(With_Frequent,FieldLengths,LEFT.FldNo=RIGHT.FldNo,AddField2(LEFT,RIGHT));

    word_cnts_rec := RECORD
      FldInv.FldNo;
      UNSIGNED2 Words := FldInv.xx_wc;
      UNSIGNED  Cnt := sum(group,FldInv.cnt);
    END;
    WordCounts := SORT(TABLE(FldInv,word_cnts_rec,FldNo,xx_wc,FEW),FldNo,-cnt);

    ResultLine_Layout AddField3(With_Lens le,WordCounts ri) := transform
      SELF.Words := le.Words+ROW({ri.Words,ri.Cnt,ROUND(ri.Cnt*10000/FldInv0[1].Cnt)/100},Words_layout);
      SELF := le;
    END;
    With_WCS := DENORMALIZE(With_Lens,WordCounts,LEFT.FldNo=RIGHT.FldNo,AddField3(LEFT,RIGHT));

    r := RECORD
      SALT_Profile.CharType c;
      UNSIGNED cnt;
      UNSIGNED2 FldNo;
    END;
    r tr(FldInv le,UNSIGNED co) := TRANSFORM
      SELF.c := ((SALT_Profile.StrType)le.Fld)[co];
      SELF := le;
    END;
    AllChars := NORMALIZE(FldInv,LEFT.xx_l,tr(LEFT,COUNTER));

    rc := RECORD
      AllChars.c;
      AllChars.FldNo;
      UNSIGNED cnt := SUM(GROUP,AllChars.cnt);
    END;
    CharCounts	:= SORT( TABLE(AllChars,rc,c,FldNo,FEW), FldNo, -Cnt );

    ResultLine_Layout AddField4(With_WCS le,CharCounts ri) := TRANSFORM
      SELF.Characters := TOPN(le.Characters+ROW({ri.c,ri.Cnt,ROUND(ri.Cnt*10000/FldInv0[1].Cnt)/100},Character_layout),MaxChars,-Cnt);
      SELF := le;
    END;
    With_Chars := DENORMALIZE(With_WCS,CharCounts,LEFT.FldNo=RIGHT.FldNo,AddField4(LEFT,RIGHT));

    dr := RECORD
      SALT_Profile.StrType Fld  {MAXLENGTH(200000)} := SALT_Profile.fn_data_pattern(FldInv.Fld);
      FldInv.Cnt;
      FldInv.FldNo;
    END;
    t := TABLE(FldInv,dr);

    r1 := RECORD
      t.Fld;
      t.FldNo;
      UNSIGNED cnt := SUM(GROUP,t.cnt);
    END;
    DataPatterns0 := SORT(DISTRIBUTE(TABLE(t,r1,FldNo,Fld,MERGE),FldNo),FldNo,-Cnt,LOCAL); // Few is slightly risky - could have many, high cardinality fields with odd patterns ...

    gcid := RECORD
      DataPatterns0;
      UNSIGNED4 ctr := 0;
    END;
    gcid iter1d(gcid le,gcid ri) := TRANSFORM
      SELF.ctr := IF (le.fldno=ri.fldno,le.ctr+1,1);
      SELF := ri;
    END;	
    first_passd := ITERATE(TABLE(DataPatterns0,gcid),iter1d(LEFT,RIGHT),LOCAL)(Ctr<=MaxExamples);

    ResultLine_Layout AddField5(With_Chars le,first_passd ri) := TRANSFORM
      SELF.Patterns := le.Patterns+ROW({ri.fld,ri.Cnt,ROUND(ri.Cnt*10000/FldInv0[1].Cnt)/100},Pattern_layout);
      SELF := le;
    END;
    RETURN DENORMALIZE(With_Chars,First_Passd,left.FldNo=right.FldNo,AddField5(left,right));
  END; // FN_Profile

  // Extended section - this deals with the case where cluster IDs and source_field information is available
  EXPORT X_Data_Layout := RECORD(Data_Layout)
    SALT_Profile.UIDType id := 0;
    SALT_Profile.StrType src := '';
  END;

  EXPORT SRC_Profile(DATASET(X_Data_Layout) TheData,DATASET(Field_Identification)TheFields) := FUNCTION
    // First get the regular counts and non-blank counts
    fldcnt := TABLE(TheData,{Cnt := COUNT(GROUP),NonBlank := COUNT(GROUP,Fld<>''),src,fldno},src,fldno,FEW);
    d := DISTRIBUTE(TheData(fld<>''),HASH(id));
    t1 := TABLE(d,{id,src,fldno,fld},id,src,fldno,fld,LOCAL);
    val_in_1 := TABLE(t1,{id,fldno,fld,c:=COUNT(GROUP)},id,fldno,fld,LOCAL)(c=1);
    srcperid := TABLE(t1,{id,fldno,src},id,fldno,src,LOCAL);
    singlesrc := TABLE(t1,{id,fldno,c:=COUNT(GROUP)},id,fldno,LOCAL)(c=1);
    srcglobal := TABLE(t1,{fldno,src,fld},src,fldno,fld,MERGE);
    srcglobalsingle := TABLE(srcglobal,{fldno,fld,msrc := MAX(GROUP,src),c := COUNT(GROUP)},fldno,fld,MERGE)(c=1);
    srcs_gs := TABLE(srcglobalsingle,{fldno,src := msrc,unique_value_global := COUNT(GROUP)},fldno,msrc,FEW);
    srcids := TABLE(srcperid,{fldno,src,TotalIdsForSrc := COUNT(GROUP)},src,fldno,FEW);

    ires := RECORD
      t1;
      BOOLEAN unique_val := FALSE; // True if the only source providing this value for this cluster
      BOOLEAN only_src := FALSE;   // True if the only source providing any value for this field for this cluster
    END;
    ires note_uval(t1 le,val_in_1 ri) := TRANSFORM
      SELF.unique_val := ri.id<>0;
      SELF := le;
    END;
    f1 := JOIN(t1,val_in_1,LEFT.id=RIGHT.id AND LEFT.fldno=RIGHT.fldno AND LEFT.fld=RIGHT.fld,note_uval(LEFT,RIGHT),LOCAL,LEFT OUTER);
  
    f1_clusters0 := TABLE(f1(unique_val), {id, fldno, src}, id, fldno, src);
    f1_clusters := TABLE(f1_clusters0, {fldno, src, unique_value_clusters := COUNT(GROUP)}, fldno, src);

    ires note_usrc(f1 le,singlesrc ri) := TRANSFORM
      SELF.only_src := ri.id<>0;
      SELF := le;
    END;
    f2 := JOIN(f1,singlesrc,LEFT.id=RIGHT.id AND LEFT.fldno=RIGHT.fldno,note_usrc(LEFT,RIGHT),LOCAL,LEFT OUTER);

    src_sums := TABLE(f2,{unique_value := COUNT(GROUP,unique_val),only_value := COUNT(GROUP,only_src),fldno,src},src,fldno,FEW);
    ss0 := JOIN(src_sums,srcs_gs,LEFT.src=RIGHT.src AND LEFT.fldno=RIGHT.fldno);
    ss1a := JOIN(ss0,srcids,LEFT.src=RIGHT.src AND LEFT.fldno=RIGHT.fldno);
    ss1 := JOIN(ss1a,f1_clusters,LEFT.src=RIGHT.src AND LEFT.fldno=RIGHT.fldno);

    rrec := RECORD
      SALT_Profile.StrType Field;
      UNSIGNED  unique_value;
      UNSIGNED  only_value;
      UNSIGNED  globally_unique_value;
      UNSIGNED  IdsWithSrc;
      UNSIGNED  unique_value_clusters;
    END;
    resrec := RECORD
      ss1.src;
      DATASET(rrec) fields := DATASET([{TheFields(fldno=ss1.fldno)[1].FieldName,ss1.unique_value,ss1.only_value,ss1.unique_value_global,ss1.TotalIdsForSrc, ss1.unique_value_clusters}],rrec);
    END;
    ss2 := TABLE(ss1,resrec);
    
    resrec rl(ss2 le,ss2 ri) := TRANSFORM
      SELF.fields := le.fields+ri.fields;
      SELF := le;
    END;
    ss3 := SORT( DISTRIBUTE(ss2,HASH(src)),src,fields[1].Field,LOCAL);
    
    RETURN SORT(ROLLUP(ss3,LEFT.src=RIGHT.src,rl(LEFT,RIGHT)),SRC);
  END; // SRC_Profile
	
END;
