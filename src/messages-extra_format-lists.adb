separate (Messages.Extra_Format)
package body Lists is

   function List_Final_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_final_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.List_Format.Separator (Locale, "standard", "final"));
   end List_Final_Separator;

   function List_Pair_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_pair_separator", Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Final_Found : Boolean;
         Final_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "list_final_separator", Final_Found);
      begin
         if Final_Found then
            return Final_Value;
         end if;
      end;

      return I18N.List_Format.Separator (Locale, "standard", "pair");
   end List_Pair_Separator;

   function List_Start_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_start_separator", Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Item_Found : Boolean;
         Item_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "list_item_separator", Item_Found);
      begin
         if Item_Found then
            return Item_Value;
         end if;
      end;

      return I18N.List_Format.Separator (Locale, "standard", "start");
   end List_Start_Separator;

   function List_Middle_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_middle_separator", Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Item_Found : Boolean;
         Item_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "list_item_separator", Item_Found);
      begin
         if Item_Found then
            return Item_Value;
         end if;
      end;

      return I18N.List_Format.Separator (Locale, "standard", "middle");
   end List_Middle_Separator;

   function Runtime_List_Separator
     (Locale : String;
      Family : String;
      Part   : String;
      Found  : out Boolean)
      return String
   is
   begin
      if Family = "standard" then
         return I18N.Runtime_Data.Locale_Text
           (Locale, "list_" & Part & "_separator", Found);
      else
         return I18N.Runtime_Data.Locale_Text
           (Locale, "list_" & Family & "_" & Part & "_separator", Found);
      end if;
   end Runtime_List_Separator;

   function Typed_Runtime_List_Separator
     (Locale   : String;
      Family   : String;
      Part     : String;
      Fallback : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        Runtime_List_Separator (Locale, Family, Part, Found);
   begin
      return (if Found then Value else Fallback);
   end Typed_Runtime_List_Separator;

   function Typed_Runtime_List_Separator
     (Locale    : String;
      Family    : String;
      Part      : String;
      Alternate : String;
      Fallback  : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        Runtime_List_Separator (Locale, Family, Part, Found);
   begin
      if Found then
         return Value;
      end if;

      return Typed_Runtime_List_Separator
        (Locale, Family, Alternate, Fallback);
   end Typed_Runtime_List_Separator;

   function Typed_Runtime_List_Separator
     (Locale     : String;
      Family     : String;
      Part       : String;
      Alternate1 : String;
      Alternate2 : String;
      Fallback   : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        Runtime_List_Separator (Locale, Family, Part, Found);
   begin
      if Found then
         return Value;
      end if;

      return Typed_Runtime_List_Separator
        (Locale, Family, Alternate1, Alternate2, Fallback);
   end Typed_Runtime_List_Separator;

   function List_Option_Is_Valid (Option : String) return Boolean is
   begin
      return Option = ""
        or else Option = "standard"
        or else Option = "and"
        or else Option = "or"
        or else Option = "disjunction"
        or else Option = "unit";
   end List_Option_Is_Valid;

   function List_Type (Option : String) return String is
   begin
      if Option = "or" or else Option = "disjunction" then
         return "or";
      elsif Option = "unit" then
         return "unit";
      else
         return "standard";
      end if;
   end List_Type;

   function Typed_List_Separator
     (Locale : String;
      Option : String;
      Count  : Natural;
      Total  : Natural)
      return String
   is
      Kind : constant String := List_Type (Option);
   begin
      if Kind = "or" then
         if Total = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "or", "pair", "final",
               I18N.List_Format.Separator (Locale, "or", "pair"));
         elsif Count = Total then
            return Typed_Runtime_List_Separator
              (Locale, "or", "final",
               I18N.List_Format.Separator (Locale, "or", "final"));
         elsif Count = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "or", "start",
               I18N.List_Format.Separator (Locale, "or", "start"));
         else
            return Typed_Runtime_List_Separator
              (Locale, "or", "middle",
               I18N.List_Format.Separator (Locale, "or", "middle"));
         end if;
      elsif Kind = "unit" then
         if Total = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "unit", "pair", "item",
               I18N.List_Format.Separator (Locale, "unit", "pair"));
         elsif Count = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "unit", "start", "item",
               I18N.List_Format.Separator (Locale, "unit", "start"));
         elsif Count = Total then
            return Typed_Runtime_List_Separator
              (Locale, "unit", "final", "middle", "item",
               I18N.List_Format.Separator (Locale, "unit", "final"));
         else
            return Typed_Runtime_List_Separator
              (Locale, "unit", "middle", "item",
               I18N.List_Format.Separator (Locale, "unit", "middle"));
         end if;
      elsif Total = 2 then
         return List_Pair_Separator (Locale);
      elsif Count = 2 then
         return List_Start_Separator (Locale);
      elsif Count = Total then
         return List_Final_Separator (Locale);
      else
         return List_Middle_Separator (Locale);
      end if;
   end Typed_List_Separator;

   procedure Format_List
     (Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Count : Natural := 1;
      Start : Positive := Value'First;

      function Item_Count return Natural is
         Result : Natural := 1;
      begin
         if Value'Length = 0 then
            return 0;
         end if;
         for C of Value loop
            if C = '|' then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Item_Count;

      Total : constant Natural := Item_Count;
      procedure Put_Item (Text : String) is
      begin
         if Count > 1 then
            Put
              (Target,
               Last,
               Overflow,
               Typed_List_Separator (Locale, Option, Count, Total));
         end if;
         Put (Target, Last, Overflow, Text);
         Count := Count + 1;
      end Put_Item;
   begin
      Ok := False;
      if Total = 0 then
         return;
      end if;

      for Index in Value'Range loop
         if Value (Index) = '|' then
            if Index = Start then
               return;
            end if;
            Put_Item (Value (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;

      if Start > Value'Last then
         return;
      end if;
      Put_Item (Value (Start .. Value'Last));
      Ok := not Overflow;
   end Format_List;

end Lists;
