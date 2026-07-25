separate (Messages.Extra_Format)
package body Relatives is

   function Relative_Option_Is_Valid (Option : String) return Boolean is
      Base : constant String := Option_Base (Option);
      Width : constant String := Option_Width (Option);
   begin
      return Option_Per_Unit (Option) = ""
        and then
          (Width = "unit-width-full-name"
           or else Width = "full-name"
           or else Width = "unit-width-long"
           or else Width = "long"
           or else Width = "unit-width-short"
           or else Width = "short"
           or else Width = "unit-width-narrow"
           or else Width = "narrow")
        and then
          (Base = "second"
           or else Base = "minute"
           or else Base = "hour"
           or else Base = "day"
           or else Base = "week"
           or else Base = "month"
           or else Base = "quarter"
           or else Base = "year");
   end Relative_Option_Is_Valid;
   function Relative_Width_Key (Option : String) return String is
      Width : constant String := Option_Width (Option);
   begin
      if Width = "unit-width-short" or else Width = "short" then
         return "unit-width-short";
      elsif Width = "unit-width-narrow" or else Width = "narrow" then
         return "unit-width-narrow";
      else
         return "unit-width-full-name";
      end if;
   end Relative_Width_Key;
   function Relative_Current (Locale : String; Option : String) return String is
      Base : constant String := Option_Base (Option);
      Width : constant String := Relative_Width_Key (Option);
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if Width = "unit-width-full-name"
            then "relative_current." & Base
            else "relative_current." & Base & "." & Width),
           Found);
   begin
      return
        (if Found then Value
         else I18N.Relative_Format.Current_Name (Locale, Base, Width));
   end Relative_Current;

   function Relative_Exact
     (Locale : String;
      Option : String;
      Offset : Long_Long_Integer;
      Found  : out Boolean)
      return String
   is
      Base : constant String := Option_Base (Option);
      Width : constant String := Relative_Width_Key (Option);
   begin
      return I18N.Runtime_Data.Locale_Text
        (Locale,
         "relative_exact." & Base & "." & Width & "."
         & Signed_Integer_Image (Offset),
         Found);
   end Relative_Exact;

   function Relative_Unit_Name
     (Locale   : String;
      Base     : String;
      Singular : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "relative_unit." & Base & "."
           & (if Singular then "one" else "other"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.Relative_Format.Unit_Display_Name
           (Locale, Base, Singular));
   end Relative_Unit_Name;

   function Relative_Unit_Name
     (Locale : String;
      Base   : String;
      Amount : Natural)
      return String
   is
      Category : constant I18N.Plurals.Plural_Category :=
        I18N.Plurals.Cardinal (Locale, Long_Long_Integer (Amount));
      Category_Name : constant String :=
        (case Category is
           when I18N.Plurals.Zero  => "zero",
           when I18N.Plurals.One   => "one",
           when I18N.Plurals.Two   => "two",
           when I18N.Plurals.Few   => "few",
           when I18N.Plurals.Many  => "many",
           when I18N.Plurals.Other => "other");
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "relative_unit." & Base & "." & Category_Name, Found);
      Generated : constant String :=
        I18N.Relative_Format.Unit_Category_Name
          (Locale, Base, Category_Name);
   begin
      if Found then
         return Value;
      end if;

      if Generated /= "" then
         return Generated;
      end if;

      if Category /= I18N.Plurals.Other then
         declare
            Other : constant String :=
              I18N.Relative_Format.Unit_Category_Name
                (Locale, Base, "other");
         begin
            if Other /= "" then
               return Other;
            end if;
         end;
      end if;

      return Relative_Unit_Name
        (Locale, Base, Category = I18N.Plurals.One);
   end Relative_Unit_Name;

   function Relative_Offset_Prefix
     (Locale : String;
      Future : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "relative_prefix." & (if Future then "future" else "past"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.Relative_Format.Offset_Prefix (Locale, Future));
   end Relative_Offset_Prefix;

   function Relative_Offset_Suffix
     (Locale : String;
      Future : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "relative_suffix." & (if Future then "future" else "past"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.Relative_Format.Offset_Suffix (Locale, Future));
   end Relative_Offset_Suffix;

   function Runtime_Relative_Override_Present
     (Locale   : String;
      Base     : String;
      Category : String;
      Future   : Boolean)
      return Boolean
   is
      Found : Boolean;
   begin
      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale,
              "relative_prefix." & (if Future then "future" else "past"),
              Found);
      begin
         if Found or else Ignored'Length > 0 then
            return True;
         end if;
      end;

      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale,
              "relative_suffix." & (if Future then "future" else "past"),
              Found);
      begin
         if Found or else Ignored'Length > 0 then
            return True;
         end if;
      end;

      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "relative_unit." & Base & "." & Category, Found);
      begin
         if Found or else Ignored'Length > 0 then
            return True;
         end if;
      end;

      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "relative_unit." & Base & ".other", Found);
      begin
         return Found or else Ignored'Length > 0;
      end;
   end Runtime_Relative_Override_Present;

   function Runtime_Relative_Time_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String;
      Future   : Boolean;
      Found    : out Boolean)
      return String
   is
      Direction : constant String := (if Future then "future" else "past");
      Field : constant String :=
        "relative_time_pattern." & Base & "." & Width & "."
        & Direction & "." & Category;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, Field, Found);
   begin
      if Found then
         return Value;
      elsif Category /= "other" then
         declare
            Other_Value : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale,
                 "relative_time_pattern." & Base & "." & Width & "."
                 & Direction & ".other",
                 Found);
         begin
            return Other_Value;
         end;
      else
         return "";
      end if;
   end Runtime_Relative_Time_Pattern;

   procedure Put_Relative_Time_Pattern
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Pattern  : String;
      Amount   : String)
   is
      Index : Natural := Pattern'First;
   begin
      while Index <= Pattern'Last loop
         if Index + 2 <= Pattern'Last
           and then Pattern (Index .. Index + 2) = "{0}"
         then
            Put (Target, Last, Overflow, Amount);
            Index := Index + 3;
         else
            Put (Target, Last, Overflow, Pattern (Index .. Index));
            Index := Index + 1;
         end if;
      end loop;
   end Put_Relative_Time_Pattern;
   procedure Put_Relative_Offset
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Option   : String;
      Amount   : Natural;
      Future   : Boolean)
   is
      Base : constant String := Option_Base (Option);
      Width : constant String := Relative_Width_Key (Option);
      Category : constant I18N.Plurals.Plural_Category :=
        I18N.Plurals.Cardinal (Locale, Long_Long_Integer (Amount));
      Category_Name : constant String := Plural_Category_Name (Category);
      Pattern : constant String :=
        I18N.Relative_Format.Time_Pattern
          (Locale, Base, Width, Category_Name, Future);
      Relative_Unit : constant String :=
        Relative_Unit_Name (Locale, Base, Amount);
      Unit : constant String :=
        (if Relative_Unit /= ""
         then Relative_Unit
         else Localized_Unit_Name
           (Locale, Option, I18N.Plurals.Cardinal
              (Locale, Long_Long_Integer (Amount)) = I18N.Plurals.One));
      Runtime_Pattern_Found : Boolean;
      Runtime_Pattern : constant String :=
        Runtime_Relative_Time_Pattern
          (Locale, Base, Width, Category_Name, Future,
           Runtime_Pattern_Found);
   begin
      if Runtime_Pattern_Found then
         declare
            Amount_Buffer : String (1 .. 64);
            Amount_Last   : Natural := 0;
            Amount_Overflow : Boolean := False;
         begin
            Put_Natural
              (Amount_Buffer, Amount_Last, Amount_Overflow, Locale, Amount);
            if not Amount_Overflow then
               Put_Relative_Time_Pattern
                 (Target,
                  Last,
                  Overflow,
                  Runtime_Pattern,
                  Amount_Buffer (1 .. Amount_Last));
               return;
            end if;
         end;
      end if;

      if Pattern /= ""
        and then not Runtime_Relative_Override_Present
          (Locale, Base, Category_Name, Future)
      then
         declare
            Amount_Buffer : String (1 .. 64);
            Amount_Last   : Natural := 0;
            Amount_Overflow : Boolean := False;
         begin
            Put_Natural
              (Amount_Buffer, Amount_Last, Amount_Overflow, Locale, Amount);
            if not Amount_Overflow then
               Put_Relative_Time_Pattern
                 (Target,
                  Last,
                  Overflow,
                  Pattern,
                  Amount_Buffer (1 .. Amount_Last));
               return;
            end if;
         end;
      end if;

      --  Caller-supplied affixes replace the built-in ones; they do not join
      --  them. A caller that gives a prefix and no suffix means "no suffix" --
      --  taking the missing half from the built-in data splices an override
      --  onto a locale that happens to exist (the fixture locale "dv" is also
      --  real Divehi, whose "+{0} d" left a stray " d" on the end).
      declare
         Overridden : constant Boolean :=
           Runtime_Relative_Override_Present
             (Locale, Base, Category_Name, Future);

         function Affix (Field : String; Built_In : String) return String is
            Found : Boolean;
            Value : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale,
                 Field & "." & (if Future then "future" else "past"),
                 Found);
         begin
            if Found then
               return Value;
            end if;

            return (if Overridden then "" else Built_In);
         end Affix;
      begin
         Put
           (Target, Last, Overflow,
            Affix ("relative_prefix", Relative_Offset_Prefix (Locale, Future)));
         Put_Natural (Target, Last, Overflow, Locale, Amount);
         Put
           (Target, Last, Overflow,
            Unit_Value_Separator (Locale));
         Put (Target, Last, Overflow, Unit);
         Put
           (Target, Last, Overflow,
            Affix ("relative_suffix", Relative_Offset_Suffix (Locale, Future)));
      end;
   end Put_Relative_Offset;
   procedure Format_Relative
     (Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Offset : Long_Long_Integer;
   begin
      Ok := False;
      if not Is_Integer_Text (Value)
        or else not Relative_Option_Is_Valid (Option)
      then
         return;
      end if;

      Offset := Long_Long_Integer'Value (Value);
      declare
         Exact_Found : Boolean;
         Exact_Value : constant String :=
           Relative_Exact (Locale, Option, Offset, Exact_Found);
      begin
         if Exact_Found then
            Put (Target, Last, Overflow, Exact_Value);
            Ok := not Overflow;
            return;
         end if;
      end;

      if Offset = 0 then
         Put (Target, Last, Overflow, Relative_Current (Locale, Option));
      elsif Offset < 0 then
         Put_Relative_Offset
           (Target, Last, Overflow, Locale, Option, Natural (abs Offset),
            False);
      else
         Put_Relative_Offset
           (Target, Last, Overflow, Locale, Option, Natural (Offset),
            True);
      end if;
      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Relative;

end Relatives;
