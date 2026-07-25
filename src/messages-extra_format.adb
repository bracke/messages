with I18N.Byte_Size_Format;
with I18N.Duration_Format;
with I18N.List_Format;
with I18N.Number_Format;
with I18N.Relative_Format;
with I18N.Unit_Format;
with I18N.Plurals;
with I18N.Runtime_Data;

package body Messages.Extra_Format is
   use type I18N.Plurals.Plural_Category;

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   function Is_Integer_Text (Text : String) return Boolean is
      Start : Positive;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if not Is_Digit (Text (Index)) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Integer_Text;

   function Is_Decimal_Text (Text : String) return Boolean is
      Start    : Positive;
      Dot      : Natural := 0;
      Saw_Digit : Boolean := False;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return False;
            end if;

            Dot := Index;
         elsif Is_Digit (Text (Index)) then
            Saw_Digit := True;
         else
            return False;
         end if;
      end loop;

      return Saw_Digit
        and then Dot /= Start
        and then Dot /= Text'Last;
   end Is_Decimal_Text;

   function Integer_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Integer_Image;

   function Signed_Integer_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      if Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      else
         return Raw;
      end if;
   end Signed_Integer_Image;

   function Plural_Category_Name
     (Category : I18N.Plurals.Plural_Category)
      return String
   is
   begin
      return
        (case Category is
           when I18N.Plurals.Zero  => "zero",
           when I18N.Plurals.One   => "one",
           when I18N.Plurals.Two   => "two",
           when I18N.Plurals.Few   => "few",
           when I18N.Plurals.Many  => "many",
           when I18N.Plurals.Other => "other");
   end Plural_Category_Name;

   function Decimal_Operands
     (Text            : String;
      Integer_Part    : out Long_Long_Integer;
      Fraction_Digits : out Natural;
      Fraction_Value  : out Long_Long_Integer)
      return Boolean
   is
      Start       : Positive := Text'First;
      Dot         : Natural := 0;
      Saw_Digit   : Boolean := False;
      Integer_Acc : Long_Long_Integer := 0;
      Fraction_Acc : Long_Long_Integer := 0;
   begin
      Integer_Part := 0;
      Fraction_Digits := 0;
      Fraction_Value := 0;

      if Text'Length = 0 then
         return False;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return False;
            end if;
            Dot := Index;
         elsif Is_Digit (Text (Index)) then
            Saw_Digit := True;
            if Dot = 0 then
               Integer_Acc :=
                 Integer_Acc * 10
                 + Long_Long_Integer
                   (Character'Pos (Text (Index)) - Character'Pos ('0'));
            else
               Fraction_Digits := Fraction_Digits + 1;
               Fraction_Acc :=
                 Fraction_Acc * 10
                 + Long_Long_Integer
                   (Character'Pos (Text (Index)) - Character'Pos ('0'));
            end if;
         else
            return False;
         end if;
      end loop;

      if not Saw_Digit
        or else Dot = Start
        or else Dot = Text'Last
      then
         return False;
      end if;

      Integer_Part := Integer_Acc;
      Fraction_Value := Fraction_Acc;
      return True;
   exception
      when Constraint_Error =>
         Integer_Part := 0;
         Fraction_Digits := 0;
         Fraction_Value := 0;
         return False;
   end Decimal_Operands;

   procedure Put
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Text     : String)
   is
   begin
      for C of Text loop
         if Last >= Target'Length then
            Overflow := True;
            return;
         end if;

         Target (Target'First + Last) := C;
         Last := Last + 1;
      end loop;
   end Put;

   procedure Put_Digit
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Digit    : Character)
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           "digit",
           Character'Pos (Digit) - Character'Pos ('0'),
           Found);
   begin
      Put
        (Target,
         Last,
         Overflow,
         (if Found then Value else I18N.Number_Format.Digit_Text (Locale, Digit)));
   end Put_Digit;

   procedure Put_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Natural;
      Width    : Natural := 1)
   is
      Raw : constant String := Integer_Image (Long_Long_Integer (Value));
   begin
      if Raw'Length < Width then
         for Pad in 1 .. Width - Raw'Length loop
            Put_Digit (Target, Last, Overflow, Locale, '0');
         end loop;
      end if;

      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Natural;

   procedure Put_Decimal_Text
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : String)
   is
      Formatted   : String (1 .. I18N.Number_Format.Max_Formatted_Length);
      Number_Last : Natural;
      Ok          : Boolean;
      Number_Ov   : Boolean;
   begin
      --  Delegate the embedded number to the i18n formatter: it groups,
      --  substitutes digits and consults the on-the-fly data -- the same
      --  rendering a top-level {number} argument gets -- rather than a parallel
      --  layout here that never grouped.
      I18N.Number_Format.Format_Into
        (Value, Locale, "", Formatted, Number_Last, Ok, Number_Ov);
      if Ok then
         Put (Target, Last, Overflow, Formatted (1 .. Number_Last));
      else
         Put (Target, Last, Overflow, Value);
      end if;
   end Put_Decimal_Text;

   function Option_Base (Option : String) return String is
      Slash : Natural := 0;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash := Index;
            exit;
         end if;
      end loop;

      declare
         Raw : constant String :=
           (if Slash = 0 then Option else Option (Option'First .. Slash - 1));
         Canon : constant String := I18N.Unit_Format.Canonical_Base (Raw);
      begin
         --  The unit-id canonicalization table lives in I18N.Unit_Format. This
         --  is called only on already-validated options, so an unrecognized Raw
         --  (Canon = "") is not expected; keep the original's lenient
         --  pass-through rather than failing.
         return (if Canon = "" then Raw else Canon);
      end;
   end Option_Base;

   function Option_Second_Slash (Option : String) return Natural is
      Seen_First : Boolean := False;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            if Seen_First then
               return Index;
            end if;

            Seen_First := True;
         end if;
      end loop;

      return 0;
   end Option_Second_Slash;

   function Option_Third_Slash (Option : String) return Natural is
      Slash_Count : Natural := 0;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash_Count := Slash_Count + 1;
            if Slash_Count = 3 then
               return Index;
            end if;
         end if;
      end loop;

      return 0;
   end Option_Third_Slash;

   function Option_Width (Option : String) return String is
      Slash        : Natural := 0;
      Second_Slash : constant Natural := Option_Second_Slash (Option);
      Third_Slash  : constant Natural := Option_Third_Slash (Option);
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash := Index;
            exit;
         end if;
      end loop;

      return
        (if Slash = 0 then "unit-width-full-name"
         elsif Second_Slash = 0 then Option (Slash + 1 .. Option'Last)
         elsif Option (Slash + 1 .. Second_Slash - 1) = "unit-width"
           and then Third_Slash = 0
         then "unit-width-" & Option (Second_Slash + 1 .. Option'Last)
         elsif Option (Slash + 1 .. Second_Slash - 1) = "unit-width"
         then "unit-width-" & Option (Second_Slash + 1 .. Third_Slash - 1)
         else Option (Slash + 1 .. Second_Slash - 1));
   end Option_Width;

   function Option_Per_Unit (Option : String) return String is
      Second_Slash : constant Natural := Option_Second_Slash (Option);
      Third_Slash  : constant Natural := Option_Third_Slash (Option);
      First_Slash  : Natural := 0;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            First_Slash := Index;
            exit;
         end if;
      end loop;

      return
        (if Second_Slash = 0 then ""
         elsif First_Slash /= 0
           and then Option (First_Slash + 1 .. Second_Slash - 1)
             = "unit-width"
           and then Third_Slash = 0
         then ""
         elsif First_Slash /= 0
           and then Option (First_Slash + 1 .. Second_Slash - 1)
             = "unit-width"
         then Option (Third_Slash + 1 .. Option'Last)
         else Option (Second_Slash + 1 .. Option'Last));
   end Option_Per_Unit;

   --  The built-in English fallback name for a unit option, used when neither
   --  a runtime override nor localized data names it. The unit-naming data
   --  itself lives in I18N.Unit_Format; this only parses the ICU option into
   --  the base and width it expects.
   function Unit_Name
     (Unit     : String;
      Singular : Boolean)
      return String
   is
     (I18N.Unit_Format.English_Name
        (Option_Base (Unit), Option_Width (Unit), Singular));

   function Locale_Unit_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Singular : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "unit." & Base & "." & Width & "."
           & (if Singular then "one" else "other"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.Unit_Format.Display_Name
           (Locale, Base, Width, (if Singular then "one" else "other")));
   end Locale_Unit_Name;

   function Locale_Unit_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : I18N.Plurals.Plural_Category)
      return String
   is
      Prefix : constant String := "unit." & Base & "." & Width & ".";

      function Runtime_Name
        (Suffix : String;
         Found  : out Boolean)
         return String
      is
      begin
         return I18N.Runtime_Data.Locale_Text (Locale, Prefix & Suffix, Found);
      end Runtime_Name;

      Found : Boolean;
      Value : constant String :=
        Runtime_Name (Plural_Category_Name (Category), Found);
   begin
      --  A runtime-provided unit name is selected by plural category, with the
      --  CLDR category fallback (category -> other -> one) so that a value
      --  whose category (for example "two" under Arabic-style rules) has no
      --  explicit row still resolves through the catalog before the built-in
      --  data is consulted.
      if Found then
         return Value;
      end if;

      if Category /= I18N.Plurals.Other then
         declare
            Other_Value : constant String := Runtime_Name ("other", Found);
         begin
            if Found then
               return Other_Value;
            end if;
         end;
      end if;

      if Category /= I18N.Plurals.One then
         declare
            One_Value : constant String := Runtime_Name ("one", Found);
         begin
            if Found then
               return One_Value;
            end if;
         end;
      end if;

      return I18N.Unit_Format.Display_Name
        (Locale, Base, Width, Plural_Category_Name (Category));
   end Locale_Unit_Name;

   function Unit_Category_For_Value
     (Locale : String;
      Value  : String)
      return I18N.Plurals.Plural_Category
   is
      Integer_Part    : Long_Long_Integer;
      Fraction_Digits : Natural;
      Fraction_Value  : Long_Long_Integer;
   begin
      if Decimal_Operands
        (Value, Integer_Part, Fraction_Digits, Fraction_Value)
      then
         return I18N.Plurals.Cardinal
           (Locale, Integer_Part, Fraction_Digits, Fraction_Value);
      else
         return I18N.Plurals.Other;
      end if;
   end Unit_Category_For_Value;

   function Runtime_Unit_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : I18N.Plurals.Plural_Category;
      Found    : out Boolean)
      return String
   is
      Field : constant String :=
        "unit_pattern." & Base & "." & Width & "."
        & Plural_Category_Name (Category);
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, Field, Found);
   begin
      if Found then
         return Value;
      elsif Category /= I18N.Plurals.Other then
         declare
            Other_Value : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale,
                 "unit_pattern." & Base & "." & Width & ".other",
                 Found);
         begin
            return Other_Value;
         end;
      else
         return "";
      end if;
   end Runtime_Unit_Pattern;

   function Unit_Option_Is_Valid (Option : String) return Boolean is
      Per_Unit : constant String := Option_Per_Unit (Option);
      Width    : constant String := Option_Width (Option);
   begin
      return Unit_Name (Option, True) /= ""
        and then
          (Per_Unit = ""
           or else Unit_Name (Per_Unit & "/" & Width, True) /= "");
   end Unit_Option_Is_Valid;

   function Localized_Unit_Name
     (Locale   : String;
      Unit     : String;
      Singular : Boolean)
      return String
   is
      Base   : constant String := Option_Base (Unit);
      Width  : constant String := Option_Width (Unit);
      Localized : constant String :=
        Locale_Unit_Name (Locale, Base, Width, Singular);
   begin
      if Localized /= "" then
         return Localized;
      end if;

      return Unit_Name (Unit, Singular);
   end Localized_Unit_Name;

   function Localized_Unit_Name
     (Locale   : String;
      Unit     : String;
      Category : I18N.Plurals.Plural_Category)
      return String
   is
      Base  : constant String := Option_Base (Unit);
      Width : constant String := Option_Width (Unit);
      Localized : constant String :=
        Locale_Unit_Name (Locale, Base, Width, Category);
   begin
      if Localized /= "" then
         return Localized;
      end if;

      return Unit_Name (Unit, Category = I18N.Plurals.One);
   end Localized_Unit_Name;

   function Localized_Unit_Name_For_Value
     (Locale : String;
      Unit   : String;
      Value  : String)
      return String
   is
   begin
      return Localized_Unit_Name
        (Locale, Unit, Unit_Category_For_Value (Locale, Value));
   end Localized_Unit_Name_For_Value;

   procedure Put_Runtime_Unit_Pattern
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Pattern  : String;
      Value    : String)
   is
      Arg : Natural := 0;
      Number_Buffer : String (1 .. 128);
      Number_Last   : Natural := 0;
      Number_Overflow : Boolean := False;
   begin
      for Index in Pattern'Range loop
         if Index <= Pattern'Last - 2
           and then Pattern (Index .. Index + 2) = "{0}"
         then
            Arg := Index;
            exit;
         end if;
      end loop;

      if Arg = 0 then
         Overflow := True;
         return;
      end if;

      Put_Decimal_Text
        (Number_Buffer, Number_Last, Number_Overflow, Locale, Value);
      if Number_Overflow then
         Overflow := True;
         return;
      end if;

      if Arg > Pattern'First then
         Put (Target, Last, Overflow, Pattern (Pattern'First .. Arg - 1));
      end if;
      Put (Target, Last, Overflow, Number_Buffer (1 .. Number_Last));
      if Arg + 2 < Pattern'Last then
         Put (Target, Last, Overflow, Pattern (Arg + 3 .. Pattern'Last));
      end if;
   end Put_Runtime_Unit_Pattern;

   function Unit_Value_Separator (Locale : String) return String is
     (I18N.Unit_Format.Value_Separator (Locale));

   function Per_Unit_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "per_unit_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.Unit_Format.Per_Unit_Separator (Locale));
   end Per_Unit_Separator;

   function Unit_Short_Per_Separator (Locale : String) return String is
     (I18N.Unit_Format.Short_Per_Separator (Locale));

   --  Does this text carry the value's placeholder -- that is, is it a pattern
   --  rather than a plain name?
   function Has_Placeholder (Text : String) return Boolean is
   begin
      for Index in Text'Range loop
         if Index <= Text'Last - 2
           and then Text (Index .. Index + 2) = "{0}"
         then
            return True;
         end if;
      end loop;

      return False;
   end Has_Placeholder;

   --  Did the caller supply this locale's per pattern at runtime? Such a row is
   --  an explicit instruction to compose the rate from its parts, so it outranks
   --  a compound name that only the generated data knows about.
   function Has_Runtime_Per_Separator (Locale : String) return Boolean is
      Found : Boolean;
      Long_Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, "per_unit_separator", Found);
      Long_Found : constant Boolean := Found;
      Short_Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "unit_short_per_separator", Found);
   begin
      pragma Unreferenced (Long_Value, Short_Value);
      return Long_Found or else Found;
   end Has_Runtime_Per_Separator;

   package Lists is
      function List_Option_Is_Valid (Option : String) return Boolean;

      procedure Format_List
        (Value    : String;
         Locale   : String;
         Option   : String;
         Target   : in out String;
         Last     : in out Natural;
         Ok       : out Boolean;
         Overflow : in out Boolean);
   end Lists;

   package body Lists is separate;

   package Relatives is
      function Relative_Option_Is_Valid (Option : String) return Boolean;

      procedure Format_Relative
        (Value    : String;
         Locale   : String;
         Option   : String;
         Target   : in out String;
         Last     : in out Natural;
         Ok       : out Boolean;
         Overflow : in out Boolean);
   end Relatives;

   package body Relatives is separate;

   function Is_Valid_Option
     (Kind   : Extra_Kind;
      Option : String)
      return Boolean
   is
   begin
      case Kind is
         when Duration | Byte_Size =>
            return Option = "";
         when List =>
            return Lists.List_Option_Is_Valid (Option);
         when Unit =>
            return Unit_Option_Is_Valid (Option);
         when Relative_Time =>
            return Relatives.Relative_Option_Is_Valid (Option);
      end case;
   end Is_Valid_Option;

   procedure Format_Duration
     (Value    : String;
      Locale   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
   begin
      --  The digital-clock duration form is a locale formatting primitive owned
      --  by i18n (like number and unit formatting); this crate only maps the
      --  ICU {n, duration} argument onto it.
      I18N.Duration_Format.Format_Into (Value, Locale, Target, Last, Ok, Overflow);
   end Format_Duration;

   procedure Format_Bytes
     (Value    : String;
      Locale   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
   begin
      --  IEC binary byte sizes are likewise an i18n formatting primitive; map
      --  the ICU {n, bytes} argument onto it.
      I18N.Byte_Size_Format.Format_Into (Value, Locale, Target, Last, Ok, Overflow);
   end Format_Bytes;

   procedure Format_Unit
     (Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
   begin
      Ok := False;
      if not Is_Decimal_Text (Value)
        or else not Unit_Option_Is_Valid (Option)
      then
         return;
      end if;

      declare
         Base     : constant String := Option_Base (Option);
         Text : constant String :=
           Localized_Unit_Name_For_Value (Locale, Option, Value);
         Per_Unit : constant String := Option_Per_Unit (Option);
         Width    : constant String := Option_Width (Option);
         Category : constant I18N.Plurals.Plural_Category :=
           Unit_Category_For_Value (Locale, Value);
         Pattern_Found : Boolean;
         Pattern : constant String :=
           Runtime_Unit_Pattern
             (Locale, Base, Width, Category, Pattern_Found);

         --  CLDR gives some rates a name of their own -- en short
         --  kilometer-per-hour is "km/h", not "km" joined to "hr" by the per
         --  pattern. Composing the parts is the fallback for the rates that
         --  have no such name, not the rule.
         Compound : constant String :=
           (if Per_Unit = "" then ""
            else Base & "-per-" & Option_Base (Per_Unit));
         Compound_Name : constant String :=
           (if Compound = "" or else Has_Runtime_Per_Separator (Locale) then ""
            else Locale_Unit_Name (Locale, Compound, Width, Category));
      begin
         if Compound_Name /= "" then
            --  Some languages seat the value inside the rate's name rather than
            --  in front of it -- Japanese "時速 {0} キロメートル". Such a row is
            --  exported whole, so render it as the pattern it is.
            if Has_Placeholder (Compound_Name) then
               Put_Runtime_Unit_Pattern
                 (Target, Last, Overflow, Locale, Compound_Name, Value);
            else
               Put_Decimal_Text (Target, Last, Overflow, Locale, Value);
               Put
                 (Target, Last, Overflow,
                  Unit_Value_Separator (Locale));
               Put (Target, Last, Overflow, Compound_Name);
            end if;
         elsif Pattern_Found and then Per_Unit = "" then
            Put_Runtime_Unit_Pattern
              (Target, Last, Overflow, Locale, Pattern, Value);
         else
            Put_Decimal_Text (Target, Last, Overflow, Locale, Value);
            Put
              (Target, Last, Overflow,
               Unit_Value_Separator (Locale));
            Put (Target, Last, Overflow, Text);
         end if;

         if Per_Unit /= "" and then Compound_Name = "" then
            if Width = "unit-width-short"
              or else Width = "short"
              or else Width = "unit-width-narrow"
              or else Width = "narrow"
            then
               Put
                 (Target, Last, Overflow,
                  Unit_Short_Per_Separator (Locale));
               Put
                 (Target, Last, Overflow,
                  Localized_Unit_Name
                    (Locale, Per_Unit & "/" & Width, True));
            else
               Put
                 (Target, Last, Overflow,
                  Per_Unit_Separator (Locale));
               Put
                 (Target, Last, Overflow,
                  Localized_Unit_Name
                    (Locale, Per_Unit & "/" & Width, True));
            end if;
         end if;
      end;

      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Unit;

   procedure Format_Into
     (Kind     : Extra_Kind;
      Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : out Natural;
      Ok       : out Boolean;
      Overflow : out Boolean)
   is
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      if not Is_Valid_Option (Kind, Option) then
         return;
      end if;

      case Kind is
         when Duration =>
            Format_Duration (Value, Locale, Target, Last, Ok, Overflow);
         when Byte_Size =>
            Format_Bytes (Value, Locale, Target, Last, Ok, Overflow);
         when Unit =>
            Format_Unit (Value, Locale, Option, Target, Last, Ok, Overflow);
         when Relative_Time =>
            Relatives.Format_Relative
              (Value, Locale, Option, Target, Last, Ok, Overflow);
         when List =>
            Lists.Format_List
              (Value, Locale, Option, Target, Last, Ok, Overflow);
      end case;
   end Format_Into;

end Messages.Extra_Format;
