IMPORT SALT_Profile;
EXPORT MAC_Correlate := MODULE
  SHARED MaxExamples := 300;
  SHARED MaxRel := 100;
  SHARED CorThresh := 1.05; // At least 5% skew to be interesting
  EXPORT Data_Layout := RECORD
    SALT_Profile.StrType Fld1 { MAXLENGTH(200000) };
    UNSIGNED2 FldNo1;
    SALT_Profile.StrType Fld2 { MAXLENGTH(200000) };
    UNSIGNED2 FldNo2;
  END;
	
  SHARED Field_Identification := SALT_Profile.MAC_Character_Counts.Field_Identification;
  SHARED Cor := RECORD
    UNSIGNED2 FldNo;
    SALT_Profile.StrType FieldName;
    REAL8 Weight;
  END;
  SHARED ResultLine_Layout := RECORD(Field_Identification)
    DATASET(Cor) Relates {MAXCOUNT(MaxRel)} := DATASET([],Cor);
  END;
  EXPORT Layout_Profile := RECORD
    SALT_Profile.StrType Fld1;
    DATASET({SALT_Profile.StrType Fld2, REAL Corr}) Correlations;
  END;
  
  // Data only comes in one way around (FldNo1 < FldNo2)
  EXPORT FN_Profile(DATASET(Data_Layout) TheData,DATASET(Field_Identification)TheFields) := FUNCTION
    IRec := RECORD
      UNSIGNED Cnt := COUNT(GROUP);
      TheData.FldNo1;
      TheData.FldNo2;
      TheData.Fld2;
      TheData.Fld1;
    END;
    FldInv1 := TABLE(TheData,IRec,Fld1,Fld2,FldNo1,FldNo2,MERGE);
    
    IRec1T := RECORD
      FldInv1.FldNo1;
      FldInv1.FldNo2;
      Cnt := SUM(GROUP,FldInv1.Cnt);
      FldInv1.Fld1;
    END;
    Fld1Tots := TABLE(FldInv1,IRec1T,Fld1,FldNo1,FldNo2,MERGE);
    
    IRec2T := RECORD
      FldInv1.FldNo1;
      FldInv1.FldNo2;
      Cnt := SUM(GROUP,FldInv1.Cnt);
      FldInv1.Fld2;
    END;
    Fld2Tots := TABLE(FldInv1,IRec2T,Fld2,FldNo1,FldNo2,MERGE);
    GTot := SUM(Fld2Tots(FldNo1=1,FldNo2=2),Cnt);
    
    F1R := RECORD
      FldInv1;
      REAL F1Pcnt;
    END;
    J1 := JOIN(FldInv1,Fld1Tots,LEFT.Fld1=RIGHT.Fld1 AND LEFT.FldNo1=RIGHT.FldNo1 AND LEFT.FLdNo2=RIGHT.FldNo2,TRANSFORM(F1R, SELF.F1Pcnt := RIGHT.Cnt/GTot, SELF := LEFT ),HASH);
    
    F2R := RECORD
      J1;
      UNSIGNED Projected;
    END;
    J2 := JOIN(J1,Fld2Tots,LEFT.Fld2=RIGHT.Fld2 AND LEFT.FldNo1=RIGHT.FldNo1 AND LEFT.FLdNo2=RIGHT.FldNo2,TRANSFORM(F2R, SELF.Projected := RIGHT.Cnt * LEFT.F1Pcnt, SELF := LEFT ),HASH);
    
    F3R := RECORD
      J2;
      REAL Ratio := IF(J2.Projected>J2.Cnt,J2.Projected/J2.Cnt,J2.Cnt/MAX(J2.Projected,1));
    END;
    T1 := TABLE(J2,F3R);
    
    FTR := RECORD
      T1.FldNo1;
      T1.FldNo2;
      CRat := SUM(GROUP,T1.Cnt*T1.Ratio);
      CT := SUM(GROUP,T1.Cnt);
    END;
    T2 := TABLE(T1,FTR,FldNo1,FldNo2,FEW);
    
    RR1 := RECORD
      SALT_Profile.StrType Fld1;
      UNSIGNED2 FldNo2;
      REAL Corr;
    END;
    RR1 TR1(T2 le,TheFields ri) := TRANSFORM
      SELF.FldNo2 := le.FldNo2;
      SELF.FLd1 := ri.FieldName;
      SELF.Corr := ((INTEGER)(100*le.Crat/le.Ct))/100;
    END;
    J3 := JOIN(T2,TheFields,LEFT.FldNo1=RIGHT.FldNo,TR1(LEFT,RIGHT),LOOKUP);
    
    RR2 := RECORD
      SALT_Profile.StrType Fld1;
      SALT_Profile.StrType Fld2;
      REAL Corr;
    END;
    J4 := JOIN(J3,TheFields,LEFT.FldNo2=RIGHT.FldNo,TRANSFORM(RR2,SELF.Fld2 := RIGHT.FieldName, SELF := LEFT),LOOKUP);
    T5 := DISTRIBUTE(J4 + PROJECT(J4,TRANSFORM(RR2,SELF.Fld1:=LEFT.Fld2,SELF.Fld2:=LEFT.Fld1,SELF := LEFT)),HASH(Fld1));
    
    Resl := RECORD
      SALT_Profile.StrType Fld2;
      REAL   Corr;
    END;		
    Resr := RECORD
      T5.Fld1;
      DATASET(Resl) Correlations := DATASET([{T5.Fld2,T5.Corr}],Resl);
    END;
    T6 := SORT( TABLE(T5(Corr>CorThresh),Resr), Fld1, LOCAL);
    
    Rl := ROLLUP( T6, LEFT.Fld1=RIGHT.Fld1, TRANSFORM(Resr, SELF.Correlations := SORT(LEFT.Correlations+RIGHT.Correlations,-Corr), SELF.Fld1 := LEFT.Fld1), LOCAL);
    RETURN SORT(Rl,-Correlations[1].Corr);
  END; // FN_Profile
	
END;
  
