with Ada.Strings.Unbounded;
with Messages.Compiled; use Messages.Compiled;
with I18N.Currency;
with I18N.Date_Time_Format;
with Messages.Extra_Format;
with I18N.Number_Format;
with I18N.Plurals;
with Ada.Containers; use Ada.Containers;
with Ada.Strings.Hash;

package body Messages.Fast_Render is

   Escaped_Number_Sign : constant Character := Character'Val (1);

   type Ordinal_Category is (One, Two, Few, Other);

   type Error_State is record
      Failed   : Boolean := False;
      Kind     : Messages.Errors.Error_Kind := Messages.Errors.Parse_Error;
      Key      : String (1 .. Messages.Diagnostics.Key_Capacity) :=
        [others => Character'Val (0)];
      Key_Last : Natural := 0;
   end record;

   procedure Store_Error_Key
     (State : in out Error_State;
      Key   : String)
   is
      Copy_Last : Natural := 0;
   begin
      State.Key := [others => Character'Val (0)];
      if Key'Length > 0 then
         Copy_Last := Natural'Min (Key'Length, State.Key'Length);
         State.Key (1 .. Copy_Last) := Key (Key'First .. Key'First + Copy_Last - 1);
      end if;
      State.Key_Last := Copy_Last;
   end Store_Error_Key;

   function Error_Key
     (State : Error_State)
      return String
   is
   begin
      if State.Key_Last = 0 then
         return "";
      end if;
      return State.Key (1 .. State.Key_Last);
   end Error_Key;

   procedure Fail
     (State : in out Error_State;
      Kind  : Messages.Errors.Error_Kind;
      Key   : String := "")
   is
   begin
      if not State.Failed then
         State.Failed := True;
         State.Kind := Kind;
         Store_Error_Key (State, Key);
      end if;
   end Fail;

   function Is_Decimal_Integer
     (Text : String)
      return Boolean
   is
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

   function To_Long_Long_Integer_Strict
     (Text  : String;
      State : in out Error_State;
      Kind  : Messages.Errors.Error_Kind;
      Key   : String := "")
      return Long_Long_Integer
   is
   begin
      if not Is_Decimal_Integer (Text) then
         Fail (State, Kind, Key);
         return 0;
      end if;

      return Long_Long_Integer'Value (Text);
   exception
      when Constraint_Error =>
         Fail (State, Kind, Key);
      return 0;
   end To_Long_Long_Integer_Strict;

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
      Integer_Part := 0;
      Fraction_Digits := 0;
      Fraction_Value := 0;
      Valid := False;

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
               return;
            end if;
            Dot := Index;
         elsif Text (Index) not in '0' .. '9' then
            return;
         end if;
      end loop;

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

   function Category_For_Ordinal
     (Value : Long_Long_Integer)
      return Ordinal_Category
   is
   begin
      if Value = 1 then
         return One;
      elsif Value = 2 then
         return Two;
      elsif Value = 3 then
         return Few;
      else
         return Other;
      end if;
   end Category_For_Ordinal;

   procedure Append_Text_With_Number_Substitution
     (Output        : in out Messages.Buffer.Buffer;
      Text          : String;
      Number_Text   : String;
      Number_Active : Boolean)
   is
   begin
      for C of Text loop
         if C = Escaped_Number_Sign then
            Output.Append ('#');
         elsif C = '#' and then Number_Active then
            Output.Append (Number_Text);
         else
            Output.Append (C);
         end if;
      end loop;
   end Append_Text_With_Number_Substitution;

   type Number_Text_Stack is
     array (Positive range <>) of String (1 .. Messages.Buffer.Default_Capacity);
   type Number_Last_Stack is array (Positive range <>) of Natural;
   type Number_Active_Stack is array (Positive range <>) of Boolean;

   procedure Push_Number_Context
     (Texts          : in out Number_Text_Stack;
      Lasts          : in out Number_Last_Stack;
      Active         : in out Number_Active_Stack;
      Top            : in out Natural;
      Current_Text   : String;
      Current_Last   : Natural;
      Current_Active : Boolean;
      State          : in out Error_State)
   is
   begin
      if Top = Texts'Last then
         Fail (State, Messages.Errors.Parse_Error);
      else
         Top := Top + 1;
         Texts (Top) := Current_Text;
         Lasts (Top) := Current_Last;
         Active (Top) := Current_Active;
      end if;
   end Push_Number_Context;

   procedure Pop_Number_Context
     (Texts          : Number_Text_Stack;
      Lasts          : Number_Last_Stack;
      Active         : Number_Active_Stack;
      Top            : in out Natural;
      Current_Text   : in out String;
      Current_Last   : in out Natural;
      Current_Active : in out Boolean;
      State          : in out Error_State)
   is
   begin
      if Top = 0 then
         Fail (State, Messages.Errors.Parse_Error);
      else
         Current_Text := Texts (Top);
         Current_Last := Lasts (Top);
         Current_Active := Active (Top);
         Top := Top - 1;
      end if;
   end Pop_Number_Context;

   procedure Store_Number_Text
     (Text         : in out String;
      Last         : out Natural;
      Value        : String;
      State        : in out Error_State;
      Error_Key    : String := "")
   is
   begin
      if Value'Length > Text'Length then
         Last := 0;
         Fail (State, Messages.Errors.Buffer_Overflow, Error_Key);
      else
         Text := [others => Character'Val (0)];
         if Value'Length > 0 then
            Text (Text'First .. Text'First + Value'Length - 1) := Value;
         end if;
         Last := Value'Length;
      end if;
   end Store_Number_Text;

   procedure Copy_Argument
     (Args     : Messages.Arguments.Arguments;
      Key      : String;
      Scratch  : out String;
      Last     : out Natural;
      Found    : out Boolean;
      Overflow : out Boolean)
   is
   begin
      Messages.Arguments.Copy_Value
        (Args     => Args,
         Key      => Key,
         Target   => Scratch,
         Last     => Last,
         Found    => Found,
         Overflow => Overflow);
   end Copy_Argument;

   function Render_Into
     (Msg         : Messages.Compiled.Compiled_Message;
      Buffer      : in out Messages.Buffer.Buffer;
      Args        : Messages.Arguments.Arguments;
      Diagnostics : in out Messages.Diagnostics.Diagnostic_List;
      Metadata    : Messages.Observability.Execution_Metadata)
      return Messages.Errors.Status
   is
      State          : Error_State;
      IP             : Positive := 1;
      Last           : constant Natural := Messages.Compiled.Last_Index (Msg);
      Number_Text    : String (1 .. Messages.Buffer.Default_Capacity) :=
        [others => Character'Val (0)];
      Number_Last    : Natural := 0;
      Number_Active  : Boolean := False;
      Number_Texts   : Number_Text_Stack (1 .. 128) :=
        [others => [others => Character'Val (0)]];
      Number_Lasts   : Number_Last_Stack (1 .. 128) := [others => 0];
      Number_Actives : Number_Active_Stack (1 .. 128) := [others => False];
      Stack_Top      : Natural := 0;
      Arg_Buffer     : String (1 .. Messages.Buffer.Default_Capacity);
      Arg_Last       : Natural := 0;
      Arg_Found      : Boolean := False;
      Arg_Overflow   : Boolean := False;
   begin
      Buffer.Clear;
      Messages.Diagnostics.Clear (Diagnostics);
      Messages.Observability.Emit
        (Messages.Observability.Message_Start,
         Messages.Observability.Message_Key (Metadata));

      while IP <= Last loop
         declare
            Operation : constant Messages.Compiled.Op := Messages.Compiled.Element (Msg, IP);
         begin
            case Operation.Kind is
               when Messages.Compiled.Text =>
                  Messages.Observability.Emit (Messages.Observability.Op_Text);
               when Messages.Compiled.Var =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Variable,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Number =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Variable,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Date_Format | Messages.Compiled.Time_Format
                  | Messages.Compiled.Date_Time_Format =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Variable,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Currency =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Variable,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Duration_Format
                  | Messages.Compiled.Byte_Size_Format
                  | Messages.Compiled.Unit_Format
                  | Messages.Compiled.Relative_Time_Format
                  | Messages.Compiled.List_Format =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Variable,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Jump_Plural =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Plural,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Jump_Select =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Select,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Jump_Ordinal =>
                  Messages.Observability.Emit
                    (Messages.Observability.Op_Ordinal,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when Messages.Compiled.Stop_Branch =>
                  null;
            end case;

            case Operation.Kind is
               when Messages.Compiled.Text =>
                  if Operation.Text_Value = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  elsif Operation.Substitute_Number_Sign then
                     Append_Text_With_Number_Substitution
                       (Output        => Buffer,
                        Text          => Operation.Text_Value.all,
                        Number_Text   =>
                          (if Number_Last = 0 then ""
                           else Number_Text (1 .. Number_Last)),
                        Number_Active => Number_Active);
                  else
                     Buffer.Append (Operation.Text_Value.all);
                  end if;
                  IP := IP + 1;

               when Messages.Compiled.Var =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow then
                        Fail (State, Messages.Errors.Buffer_Overflow);
                     elsif Arg_Last > 0 then
                        Buffer.Append (Arg_Buffer (1 .. Arg_Last));
                        IP := IP + 1;
                     else
                        IP := IP + 1;
                     end if;
                  end if;

               when Messages.Compiled.Number =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow then
                        Fail (State, Messages.Errors.Buffer_Overflow);
                     else
                        declare
                           Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
                           Formatted_Last : Natural;
                           Ok : Boolean;
                           Format_Overflow : Boolean;
                        begin
                           I18N.Number_Format.Format_Into
                             (Value_Text =>
                                (if Arg_Last = 0 then "" else Arg_Buffer (1 .. Arg_Last)),
                              Locale     => "en",
                              Style      =>
                                (if Operation.Currency_Code = null
                                 then "" else Operation.Currency_Code.all),
                              Target     => Formatted,
                              Last       => Formatted_Last,
                              Ok         => Ok,
                              Overflow   => Format_Overflow);

                           if Format_Overflow then
                              Fail (State, Messages.Errors.Buffer_Overflow);
                           elsif not Ok then
                              Fail
                                (State,
                                 Messages.Errors.Invalid_Selector,
                                 Operation.Key.all);
                           elsif Formatted_Last > 0 then
                              Buffer.Append (Formatted (1 .. Formatted_Last));
                              IP := IP + 1;
                           else
                              IP := IP + 1;
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Date_Format | Messages.Compiled.Time_Format
                  | Messages.Compiled.Date_Time_Format =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow then
                        Fail (State, Messages.Errors.Buffer_Overflow);
                     else
                        declare
                           Formatted : String (1 .. I18N.Date_Time_Format.Max_Formatted_Length);
                           Formatted_Last : Natural;
                           Ok : Boolean;
                           Format_Overflow : Boolean;
                        begin
                           if Operation.Kind = Messages.Compiled.Date_Format then
                              I18N.Date_Time_Format.Format_Date_Into
                                (Value_Text =>
                                   (if Arg_Last = 0 then "" else Arg_Buffer (1 .. Arg_Last)),
                                 Locale     => "en",
                                 Style      =>
                                   (if Operation.Currency_Code = null
                                    then "" else Operation.Currency_Code.all),
                                 Target     => Formatted,
                                 Last       => Formatted_Last,
                                 Ok         => Ok,
                                 Overflow   => Format_Overflow);
                           elsif Operation.Kind = Messages.Compiled.Time_Format then
                              I18N.Date_Time_Format.Format_Time_Into
                                (Value_Text =>
                                   (if Arg_Last = 0 then "" else Arg_Buffer (1 .. Arg_Last)),
                                 Locale     => "en",
                                 Style      =>
                                   (if Operation.Currency_Code = null
                                    then "" else Operation.Currency_Code.all),
                                 Target     => Formatted,
                                 Last       => Formatted_Last,
                                 Ok         => Ok,
                                 Overflow   => Format_Overflow);
                           else
                              I18N.Date_Time_Format.Format_Date_Time_Into
                                (Value_Text =>
                                   (if Arg_Last = 0 then "" else Arg_Buffer (1 .. Arg_Last)),
                                 Locale     => "en",
                                 Style      =>
                                   (if Operation.Currency_Code = null
                                    then "" else Operation.Currency_Code.all),
                                 Target     => Formatted,
                                 Last       => Formatted_Last,
                                 Ok         => Ok,
                                 Overflow   => Format_Overflow);
                           end if;

                           if Format_Overflow then
                              Fail (State, Messages.Errors.Buffer_Overflow);
                           elsif not Ok then
                              Fail
                                (State,
                                 Messages.Errors.Invalid_Selector,
                                 Operation.Key.all);
                           elsif Formatted_Last > 0 then
                              Buffer.Append (Formatted (1 .. Formatted_Last));
                              IP := IP + 1;
                           else
                              IP := IP + 1;
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Currency =>
                  if Operation.Key = null or else Operation.Currency_Code = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow then
                        Fail (State, Messages.Errors.Buffer_Overflow);
                     else
                        declare
                           Formatted : String (1 .. I18N.Currency.Max_Formatted_Length);
                           Formatted_Last : Natural;
                           Ok : Boolean;
                           Format_Overflow : Boolean;
                        begin
                           I18N.Currency.Format_Into
                             (Amount_Text   =>
                                (if Arg_Last = 0 then "" else Arg_Buffer (1 .. Arg_Last)),
                              Currency_Code => Operation.Currency_Code.all,
                              Locale        => "en",
                              Target        => Formatted,
                              Last          => Formatted_Last,
                              Ok            => Ok,
                              Overflow      => Format_Overflow);

                           if Format_Overflow then
                              Fail (State, Messages.Errors.Buffer_Overflow);
                           elsif not Ok then
                              Fail
                                (State,
                                 Messages.Errors.Invalid_Selector,
                                 Operation.Key.all);
                           elsif Formatted_Last > 0 then
                              Buffer.Append (Formatted (1 .. Formatted_Last));
                              IP := IP + 1;
                           else
                              IP := IP + 1;
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Duration_Format
                  | Messages.Compiled.Byte_Size_Format
                  | Messages.Compiled.Unit_Format
                  | Messages.Compiled.Relative_Time_Format
                  | Messages.Compiled.List_Format =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow then
                        Fail (State, Messages.Errors.Buffer_Overflow);
                     else
                        declare
                           Formatted : String (1 .. Messages.Extra_Format.Max_Formatted_Length);
                           Formatted_Last : Natural;
                           Ok : Boolean;
                           Format_Overflow : Boolean;

                           function Kind return Messages.Extra_Format.Extra_Kind is
                           begin
                              case Operation.Kind is
                                 when Messages.Compiled.Duration_Format =>
                                    return Messages.Extra_Format.Duration;
                                 when Messages.Compiled.Byte_Size_Format =>
                                    return Messages.Extra_Format.Byte_Size;
                                 when Messages.Compiled.Unit_Format =>
                                    return Messages.Extra_Format.Unit;
                                 when Messages.Compiled.Relative_Time_Format =>
                                    return Messages.Extra_Format.Relative_Time;
                                 when others =>
                                    return Messages.Extra_Format.List;
                              end case;
                           end Kind;
                        begin
                           Messages.Extra_Format.Format_Into
                             (Kind     => Kind,
                              Value    =>
                                (if Arg_Last = 0 then "" else Arg_Buffer (1 .. Arg_Last)),
                              Locale   => "en",
                              Option   =>
                                (if Operation.Currency_Code = null
                                 then "" else Operation.Currency_Code.all),
                              Target   => Formatted,
                              Last     => Formatted_Last,
                              Ok       => Ok,
                              Overflow => Format_Overflow);

                           if Format_Overflow then
                              Fail (State, Messages.Errors.Buffer_Overflow);
                           elsif not Ok then
                              Fail
                                (State,
                                 Messages.Errors.Invalid_Selector,
                                 Operation.Key.all);
                           elsif Formatted_Last > 0 then
                              Buffer.Append (Formatted (1 .. Formatted_Last));
                              IP := IP + 1;
                           else
                              IP := IP + 1;
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Jump_Plural =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow or else Arg_Last = 0 then
                        Fail (State, Messages.Errors.Invalid_Selector, Operation.Key.all);
                     else
                        declare
                           Raw_Text : constant String := Arg_Buffer (1 .. Arg_Last);
                           Category : I18N.Plurals.Plural_Category :=
                             I18N.Plurals.Other;
                           Target   : Messages.Compiled.Op_Index :=
                             Operation.Other_Target;
                           Exact_Match_Allowed : Boolean := False;
                           Exact_Value : Long_Long_Integer := 0;
                           Rendered : String (1 .. Messages.Buffer.Default_Capacity) :=
                             [others => Character'Val (0)];
                           Rendered_Last : Natural := 0;
                        begin
                           if Operation.Plural_Offset /= 0 then
                              Exact_Value :=
                                To_Long_Long_Integer_Strict
                                  (Text  => Raw_Text,
                                   State => State,
                                   Kind  => Messages.Errors.Invalid_Selector,
                                   Key   => Operation.Key.all);
                              if not State.Failed then
                                 declare
                                    Adjusted : constant Long_Long_Integer :=
                                      Exact_Value - Operation.Plural_Offset;
                                    Rendered_Image : constant String :=
                                      Integer_Image_No_Leading_Space
                                        (Adjusted);
                                 begin
                                    Category :=
                                      I18N.Plurals.Cardinal ("en", Adjusted);
                                    Store_Number_Text
                                      (Rendered, Rendered_Last, Rendered_Image,
                                       State, Operation.Key.all);
                                    Exact_Match_Allowed := True;
                                 end;
                              end if;
                           elsif Is_Decimal_Integer (Raw_Text) then
                              Exact_Value :=
                                To_Long_Long_Integer_Strict
                                  (Text  => Raw_Text,
                                   State => State,
                                   Kind  => Messages.Errors.Invalid_Selector,
                                   Key   => Operation.Key.all);
                              if not State.Failed then
                                 declare
                                    Rendered_Image : constant String :=
                                      Integer_Image_No_Leading_Space
                                        (Exact_Value);
                                 begin
                                    Category :=
                                      I18N.Plurals.Cardinal ("en", Exact_Value);
                                    Store_Number_Text
                                      (Rendered, Rendered_Last, Rendered_Image,
                                       State, Operation.Key.all);
                                    Exact_Match_Allowed := True;
                                 end;
                              end if;
                           else
                              declare
                                 I_Part      : Long_Long_Integer;
                                 Digit_Count : Natural;
                                 F_Val       : Long_Long_Integer;
                                 Valid       : Boolean;
                              begin
                                 Split_Decimal
                                   (Raw_Text, I_Part, Digit_Count, F_Val, Valid);
                                 if Valid then
                                    Category :=
                                      I18N.Plurals.Cardinal
                                        ("en", I_Part, Digit_Count, F_Val);
                                    Store_Number_Text
                                      (Rendered, Rendered_Last, Raw_Text, State,
                                       Operation.Key.all);
                                 else
                                    Fail
                                      (State,
                                       Messages.Errors.Invalid_Selector,
                                       Operation.Key.all);
                                 end if;
                              end;
                           end if;

                           if not State.Failed then
                              Push_Number_Context
                                (Texts          => Number_Texts,
                                 Lasts          => Number_Lasts,
                                 Active         => Number_Actives,
                                 Top            => Stack_Top,
                                 Current_Text   => Number_Text,
                                 Current_Last   => Number_Last,
                                 Current_Active => Number_Active,
                                 State          => State);
                              Number_Text := Rendered;
                              Number_Last := Rendered_Last;
                              Number_Active := True;

                              if Exact_Match_Allowed
                                and then Operation.Exact_Targets /= null
                              then
                                 for Exact of Operation.Exact_Targets.all loop
                                    if Exact.Value = Exact_Value then
                                       Target := Exact.Target;
                                       exit;
                                    end if;
                                 end loop;
                              end if;

                              if Target = Operation.Other_Target then
                                 case Category is
                                    when I18N.Plurals.Zero =>
                                       if Operation.Zero_Target /= 0 then
                                          Target := Operation.Zero_Target;
                                       end if;
                                    when I18N.Plurals.One =>
                                       if Operation.One_Target /= 0 then
                                          Target := Operation.One_Target;
                                       end if;
                                    when I18N.Plurals.Two =>
                                       if Operation.Two_Target /= 0 then
                                          Target := Operation.Two_Target;
                                       end if;
                                    when I18N.Plurals.Few =>
                                       if Operation.Few_Target /= 0 then
                                          Target := Operation.Few_Target;
                                       end if;
                                    when I18N.Plurals.Many =>
                                       if Operation.Many_Target /= 0 then
                                          Target := Operation.Many_Target;
                                       end if;
                                    when I18N.Plurals.Other =>
                                       null;
                                 end case;
                              end if;

                              if not State.Failed then
                                 IP := Positive (Target);
                              end if;
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Jump_Select =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     else
                        declare
                           Target   : Messages.Compiled.Op_Index := Operation.Other_Target;
                           Arg_Hash : constant Ada.Containers.Hash_Type :=
                             (if Arg_Overflow or else Arg_Last = 0
                              then 0
                              else Ada.Strings.Hash (Arg_Buffer (1 .. Arg_Last)));
                        begin
                           if not Arg_Overflow
                             and then Operation.Select_Targets /= null
                           then
                              for Choice of Operation.Select_Targets.all loop
                                 if Choice.Name /= null
                                   and then Choice.Target /= 0
                                   and then Arg_Hash = Choice.Hash
                                   and then Arg_Last = Choice.Name.all'Length
                                   and then Arg_Buffer (1 .. Arg_Last)
                                     = Choice.Name.all
                                 then
                                    Target := Choice.Target;
                                    exit;
                                 end if;
                              end loop;
                           end if;

                           if Target = 0 then
                              Fail (State, Messages.Errors.Missing_Branch, Operation.Key.all);
                           else
                              IP := Positive (Target);
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Jump_Ordinal =>
                  if Operation.Key = null then
                     Fail (State, Messages.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, Messages.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow or else Arg_Last = 0 then
                        Fail (State, Messages.Errors.Invalid_Ordinal, Operation.Key.all);
                     else
                        declare
                           Numeric_Value : constant Long_Long_Integer :=
                             To_Long_Long_Integer_Strict
                               (Text  => Arg_Buffer (1 .. Arg_Last),
                                State => State,
                                Kind  => Messages.Errors.Invalid_Ordinal,
                                Key   => Operation.Key.all);
                        begin
                           if not State.Failed then
                              declare
                                 Rendered_Image : constant String :=
                                   Integer_Image_No_Leading_Space
                                     (Numeric_Value);
                              begin
                                 Push_Number_Context
                                   (Texts          => Number_Texts,
                                    Lasts          => Number_Lasts,
                                    Active         => Number_Actives,
                                    Top            => Stack_Top,
                                    Current_Text   => Number_Text,
                                    Current_Last   => Number_Last,
                                    Current_Active => Number_Active,
                                    State          => State);
                                 Store_Number_Text
                                   (Number_Text, Number_Last, Rendered_Image,
                                    State, Operation.Key.all);
                                 Number_Active := True;
                              end;
                              --  Only "other" is mandatory; an absent category
                              --  branch (target 0) falls back to "other".
                              declare
                                 Target : Messages.Compiled.Op_Index :=
                                   Operation.Other_Target;
                              begin
                                 if Operation.Exact_Targets /= null then
                                    for Exact of Operation.Exact_Targets.all loop
                                       if Exact.Value = Numeric_Value then
                                          Target := Exact.Target;
                                          exit;
                                       end if;
                                    end loop;
                                 end if;

                                 if Target = Operation.Other_Target then
                                    case Category_For_Ordinal (Numeric_Value) is
                                       when One =>
                                          if Operation.One_Target /= 0 then
                                             Target := Operation.One_Target;
                                          end if;
                                       when Two =>
                                          if Operation.Two_Target /= 0 then
                                             Target := Operation.Two_Target;
                                          end if;
                                       when Few =>
                                          if Operation.Few_Target /= 0 then
                                             Target := Operation.Few_Target;
                                          end if;
                                       when Other =>
                                          null;
                                    end case;
                                 end if;
                                 IP := Positive (Target);
                              end;
                           end if;
                        end;
                     end if;
                  end if;

               when Messages.Compiled.Stop_Branch =>
                  if Operation.Restores_Number_Context then
                     Pop_Number_Context
                       (Texts          => Number_Texts,
                        Lasts          => Number_Lasts,
                        Active         => Number_Actives,
                        Top            => Stack_Top,
                        Current_Text   => Number_Text,
                        Current_Last   => Number_Last,
                        Current_Active => Number_Active,
                        State          => State);
                  end if;

                  if not State.Failed then
                     IP := Positive (Operation.End_Target);
                  end if;
            end case;
         end;

         if Buffer.Overflowed then
            Fail (State, Messages.Errors.Buffer_Overflow);
         end if;

         exit when State.Failed;
      end loop;

      Messages.Observability.Emit (Messages.Observability.Message_End);

      if State.Failed then
         Messages.Diagnostics.Add
           (List    => Diagnostics,
            Kind    => Messages.Errors.To_Diagnostic_Kind (State.Kind),
            Message => "render failure",
            Key     => Error_Key (State));
         return Messages.Errors.Failure_Status (State.Kind);
      end if;

      return Messages.Errors.Success_Status;
   exception
      when others =>
         Messages.Diagnostics.Add
           (List    => Diagnostics,
            Kind    => Messages.Diagnostics.Parse_Error,
            Message => "render exception");
         Messages.Observability.Emit (Messages.Observability.Message_End);
         return Messages.Errors.Failure_Status (Messages.Errors.Parse_Error);
   end Render_Into;

   function Render_Into
     (Msg         : Messages.Compiled.Compiled_Message;
      Buffer      : in out Messages.Buffer.Buffer;
      Args        : Messages.Arguments.Arguments;
      Diagnostics : in out Messages.Diagnostics.Diagnostic_List)
      return Messages.Errors.Status
   is
      Metadata : Messages.Observability.Execution_Metadata;
   begin
      return Render_Into
        (Msg         => Msg,
         Buffer      => Buffer,
         Args        => Args,
         Diagnostics => Diagnostics,
         Metadata    => Metadata);
   end Render_Into;

   function Render_Into
     (Msg    : Messages.Compiled.Compiled_Message;
      Buffer : in out Messages.Buffer.Buffer;
      Args   : Messages.Arguments.Arguments)
      return Messages.Errors.Status
   is
      Diagnostics : Messages.Diagnostics.Diagnostic_List;
   begin
      return Render_Into
        (Msg         => Msg,
         Buffer      => Buffer,
         Args        => Args,
         Diagnostics => Diagnostics);
   end Render_Into;

   function Render
     (Msg    : Messages.Compiled.Compiled_Message;
      Buffer : in out Messages.Buffer.Buffer;
      Args   : Messages.Arguments.Arguments)
      return Messages.Errors.Result
   is
      Diagnostics : Messages.Diagnostics.Diagnostic_List;
      Status      : Messages.Errors.Status;
   begin
      Status := Render_Into
        (Msg         => Msg,
         Buffer      => Buffer,
         Args        => Args,
         Diagnostics => Diagnostics);

      if not Status.Ok then
         declare
            Result : constant Messages.Errors.Result := Messages.Errors.Failure (Status.Error);
         begin
            return
              (Ok          => Result.Ok,
               Value       => Result.Value,
               Error       => Result.Error,
               Diagnostics => Diagnostics);
         end;
      end if;

      declare
         Value : constant String := Buffer.To_String;
      begin
         return
           (Ok          => True,
            Value       => Ada.Strings.Unbounded.To_Unbounded_String (Value),
            Error       => Messages.Errors.Parse_Error,
            Diagnostics => Diagnostics);
      end;
   end Render;

   function Render
     (Msg  : Messages.Compiled.Compiled_Message;
      Args : Messages.Arguments.Arguments)
      return Messages.Errors.Result
   is
      Buffer : Messages.Buffer.Buffer;
   begin
      return Render (Msg => Msg, Buffer => Buffer, Args => Args);
   end Render;

end Messages.Fast_Render;
