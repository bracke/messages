separate (Messages.Parser)
procedure Parse_Number
  (Source : String;
   Pos    : in out Positive;
   Name   : String;
   Head   : in out Messages.AST.Node_Access;
   Tail   : in out Messages.AST.Node_Access)
is
   Option : constant String := Read_Format_Option (Source, Pos);

   function Currency_Style_From_Skeleton
     (Style : String;
      Target : out String;
      Last   : out Natural)
      return Boolean
   is
      Prefix : constant String := "::currency/";
      Pos    : Positive;
      Token_End : Natural;
      Code_Start : Positive;
      Code_End   : Natural;
      Code        : String (1 .. 3);
      Display     : Unbounded_String := Null_Unbounded_String;
      Cash        : Boolean := False;
      Accounting  : Boolean := False;

      function Apply_Token (Token : String) return Boolean is
      begin
         if Token = "" then
            return False;
         elsif Token = "symbol"
           or else Token = "unit-width-short"
           or else Token = "unit-width/short"
           or else Token = "standard"
         then
            Display := Null_Unbounded_String;
         elsif Token = "narrow"
           or else Token = "unit-width-narrow"
           or else Token = "unit-width/narrow"
         then
            Display := To_Unbounded_String ("unit-width-narrow");
         elsif Token = "name"
           or else Token = "unit-width-full-name"
           or else Token = "unit-width/full-name"
           or else Token = "unit-width-long"
           or else Token = "unit-width/long"
           or else Token = "full-name"
         then
            Display := To_Unbounded_String ("unit-width-full-name");
         elsif Token = "unit-width-iso-code"
           or else Token = "unit-width/iso-code"
           or else Token = "iso-code"
         then
            Display := To_Unbounded_String ("unit-width-iso-code");
         elsif Token = "cash"
           or else Token = "precision-currency-cash"
           or else Token = "precision-currency/cash"
           or else Token = "precision/currency-cash"
           or else Token = "::precision-currency-cash"
         then
            Cash := True;
         elsif Token = "precision-currency-standard"
           or else Token = "precision-currency/standard"
           or else Token = "precision/currency-standard"
           or else Token = "::precision-currency-standard"
         then
            Cash := False;
         elsif Token = "accounting"
           or else Token = "sign-accounting"
           or else Token = "sign/accounting"
         then
            Accounting := True;
         else
            return False;
         end if;

         return True;
      end Apply_Token;
   begin
      Last := 0;

      if Style'Length < Prefix'Length + 3
        or else Style (Style'First .. Style'First + Prefix'Length - 1)
          /= Prefix
      then
         return False;
      end if;

      Code_Start := Style'First + Prefix'Length;
      Code_End := Code_Start + 2;
      if Code_End > Style'Last then
         return False;
      end if;

      Code := Style (Code_Start .. Code_End);
      if not I18N.Currency.Is_Valid_Code (Code) then
         return False;
      end if;

      if Code_End = Style'Last then
         Target (Target'First .. Target'First + 2) := Code;
         Last := 3;
         return True;
      elsif Style (Code_End + 1) = '/' then
         declare
            Existing : constant String := Style (Code_Start .. Style'Last);
         begin
            if I18N.Currency.Is_Valid_Code (Existing) then
               Target (Target'First .. Target'First + Existing'Length - 1) :=
                 Existing;
               Last := Existing'Length;
               return True;
            else
               return False;
            end if;
         end;
      elsif Style (Code_End + 1) /= ' ' then
         return False;
      end if;

      Pos := Code_End + 1;
      while Pos <= Style'Last loop
         while Pos <= Style'Last and then Style (Pos) = ' ' loop
            Pos := Pos + 1;
         end loop;

         exit when Pos > Style'Last;

         Token_End := Pos;
         while Token_End <= Style'Last
           and then Style (Token_End) /= ' '
         loop
            Token_End := Token_End + 1;
         end loop;

         if not Apply_Token (Style (Pos .. Token_End - 1)) then
            return False;
         end if;

         Pos := Token_End;
      end loop;

      declare
         Variant : Unbounded_String := Null_Unbounded_String;
      begin
         if Cash then
            Variant := To_Unbounded_String ("cash");
         end if;

         if Length (Display) > 0 then
            if Length (Variant) > 0 then
               Append (Variant, "-");
            end if;
            Append (Variant, To_String (Display));
         end if;

         if Accounting then
            if Length (Variant) > 0 then
               Append (Variant, "-");
            end if;
            Append (Variant, "accounting");
         end if;

         if Length (Variant) = 0 then
            Target (Target'First .. Target'First + 2) := Code;
            Last := 3;
         else
            declare
               Text : constant String := Code & "/" & To_String (Variant);
            begin
               if Text'Length > Target'Length then
                  return False;
               end if;
               Target (Target'First .. Target'First + Text'Length - 1) :=
                 Text;
               Last := Text'Length;
            end;
         end if;
      end;

      return I18N.Currency.Is_Valid_Code
        (Target (Target'First .. Target'First + Last - 1));
   end Currency_Style_From_Skeleton;

   function Unit_Style_From_Skeleton
     (Style  : String;
      Target : out String;
      Last   : out Natural)
      return Boolean
   is
      Prefix : constant String := "::measure-unit/";
      Pos    : Positive;
      Token_End : Natural;
      Unit_Start : Positive;
      Unit_End   : Natural;
      Width      : Unbounded_String :=
        To_Unbounded_String ("unit-width-full-name");
      Per_Unit   : Unbounded_String := Null_Unbounded_String;
      function Apply_Token (Token : String) return Boolean is
      begin
         if Token = "unit-width-full-name"
           or else Token = "unit-width/full-name"
           or else Token = "unit-width-long"
           or else Token = "unit-width/long"
           or else Token = "full-name"
         then
            Width := To_Unbounded_String ("unit-width-full-name");
         elsif Token = "unit-width-short"
           or else Token = "unit-width/short"
           or else Token = "short"
         then
            Width := To_Unbounded_String ("unit-width-short");
         elsif Token = "unit-width-narrow"
           or else Token = "unit-width/narrow"
           or else Token = "narrow"
         then
            Width := To_Unbounded_String ("unit-width-narrow");
         elsif Token'Length > 17
           and then Token (Token'First .. Token'First + 16)
             = "per-measure-unit/"
         then
            declare
               Unit_Text : constant String :=
                 I18N.Unit_Format.Canonical_Base (Token (Token'First + 17 .. Token'Last));
            begin
               if Unit_Text = "" or else Length (Per_Unit) > 0 then
                  return False;
               end if;

               Per_Unit := To_Unbounded_String (Unit_Text);
            end;
         else
            return False;
         end if;

         return True;
      end Apply_Token;
   begin
      Last := 0;

      if Style'Length < Prefix'Length + 1
        or else Style (Style'First .. Style'First + Prefix'Length - 1)
          /= Prefix
      then
         return False;
      end if;

      Unit_Start := Style'First + Prefix'Length;
      Unit_End := Unit_Start;
      while Unit_End <= Style'Last
        and then Style (Unit_End) /= ' '
      loop
         Unit_End := Unit_End + 1;
      end loop;

      declare
         Unit : constant String :=
           I18N.Unit_Format.Canonical_Base (Style (Unit_Start .. Unit_End - 1));
      begin
         if Unit = "" then
            return False;
         end if;

         Pos := Unit_End;
         while Pos <= Style'Last loop
            while Pos <= Style'Last and then Style (Pos) = ' ' loop
               Pos := Pos + 1;
            end loop;

            exit when Pos > Style'Last;

            Token_End := Pos;
            while Token_End <= Style'Last
              and then Style (Token_End) /= ' '
            loop
               Token_End := Token_End + 1;
            end loop;

            if not Apply_Token (Style (Pos .. Token_End - 1)) then
               return False;
            end if;

            Pos := Token_End;
         end loop;

         declare
            Text : constant String :=
              Unit & "/" & To_String (Width)
              & (if Length (Per_Unit) = 0
                 then ""
                 else "/" & To_String (Per_Unit));
         begin
            if Text'Length > Target'Length
              or else not Messages.Extra_Format.Is_Valid_Option
                (Messages.Extra_Format.Unit, Text)
            then
               return False;
            end if;

            Target (Target'First .. Target'First + Text'Length - 1) :=
              Text;
            Last := Text'Length;
         end;
      end;

      return True;
   end Unit_Style_From_Skeleton;
begin
   if Pos > Source'Last then
      Raise_Unbalanced_Braces ("Expected '}' after number keyword");
   elsif Source (Pos) /= '}' then
      raise Parse_Error with "Expected '}' after number keyword";
   end if;

   Pos := Pos + 1;

   if Option = "" then
      Messages.AST.Append_Number
        (Head => Head,
         Tail => Tail,
         Name => Name);
   elsif Option'Length > 11
     and then Option (Option'First .. Option'First + 10) = "::currency/"
   then
      declare
         Code_And_Option : String (1 .. Option'Length);
         Code_Last       : Natural;
      begin
         if not Currency_Style_From_Skeleton
           (Option, Code_And_Option, Code_Last)
         then
            raise Parse_Error with "Unsupported currency skeleton";
         end if;

         Messages.AST.Append_Currency
           (Head          => Head,
            Tail          => Tail,
            Name          => Name,
            Currency_Code => Code_And_Option (1 .. Code_Last));
      end;
   elsif Option'Length > 15
     and then Option (Option'First .. Option'First + 14)
       = "::measure-unit/"
   then
      declare
         Unit_Option : String (1 .. Option'Length + 32);
         Unit_Last   : Natural;
      begin
         if not Unit_Style_From_Skeleton
           (Option, Unit_Option, Unit_Last)
         then
            raise Parse_Error with "Unsupported measure-unit skeleton";
         end if;

         Messages.AST.Append_Extra_Format
           (Head   => Head,
            Tail   => Tail,
            Kind   => Messages.AST.Unit_Format,
            Name   => Name,
            Option => Unit_Option (1 .. Unit_Last));
      end;
   elsif I18N.Number_Format.Is_Valid_Style (Option) then
      Messages.AST.Append_Number
        (Head  => Head,
         Tail  => Tail,
         Name  => Name,
         Style => Option);
   else
      raise Parse_Error with "Unsupported number skeleton";
   end if;
end Parse_Number;
