package body Messages.Numeric_Text is

   function Is_Decimal_Integer (Text : String) return Boolean is
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
         if Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Decimal_Integer;

   procedure Split_Decimal
     (Text            : String;
      Integer_Part    : out Long_Long_Integer;
      Fraction_Digits : out Natural;
      Fraction_Value  : out Long_Long_Integer;
      Valid           : out Boolean)
   is
      Start : Natural := Text'First;
      Dot   : Natural := 0;
   begin
      Integer_Part    := 0;
      Fraction_Digits := 0;
      Fraction_Value  := 0;
      Valid           := False;

      if Text'Length = 0 then
         return;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return;  --  more than one '.'
            end if;
            Dot := Index;
         elsif Text (Index) not in '0' .. '9' then
            return;     --  non-digit
         end if;
      end loop;

      --  Need digits before and after a single dot.
      if Dot = 0 or else Dot = Start or else Dot = Text'Last then
         return;
      end if;

      Integer_Part := Long_Long_Integer'Value (Text (Start .. Dot - 1));
      Fraction_Digits := Text'Last - Dot;
      Fraction_Value := Long_Long_Integer'Value (Text (Dot + 1 .. Text'Last));
      Valid := True;
   exception
      when Constraint_Error =>
         Valid := False;
   end Split_Decimal;

   function Integer_Image_No_Leading_Space
     (Value : Long_Long_Integer)
      return String
   is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Integer_Image_No_Leading_Space;

end Messages.Numeric_Text;
