private package Messages.Numeric_Text is
   --  Shared string<->number primitives used by every ICU render path
   --  (Messages.Runtime, Messages.Render, Messages.Fast_Render). These encode
   --  the engine's argument-string parsing/formatting contract; keeping a single
   --  copy stops the render paths from drifting on integer/decimal edge cases.

   --  Sentinel a compiled/parsed message carries in place of a literal '#' that
   --  must render as '#' rather than as the substituted number.
   Escaped_Number_Sign : constant Character := Character'Val (1);

   --  True when Text is a bare, optionally-signed run of decimal digits.
   function Is_Decimal_Integer (Text : String) return Boolean;

   --  Split a decimal string ("12.50", "-1.5") into CLDR operands. Requires at
   --  least one digit on each side of a single '.'; sets Valid := False for any
   --  other shape (including a plain integer with no fraction).
   procedure Split_Decimal
     (Text            : String;
      Integer_Part    : out Long_Long_Integer;
      Fraction_Digits : out Natural;
      Fraction_Value  : out Long_Long_Integer;
      Valid           : out Boolean);

   --  Long_Long_Integer'Image without the leading space Ada emits on
   --  non-negative values.
   function Integer_Image_No_Leading_Space
     (Value : Long_Long_Integer)
      return String;

end Messages.Numeric_Text;
