separate (Messages.Runtime)
procedure Render_Sink
  (Root          : Messages.AST.Node_Access;
   Arguments     : Messages.Arguments.Arguments;
   Sink          : in out Sink_Type;
   Status        : in out Messages.Result.Render_Status;
   Diagnostics   : in out Messages.Diagnostics.Diagnostic_List;
   Locale        : String;
   Number_Text   : String := "";
   Number_Active : Boolean := False)
is
   Current : Messages.AST.Node_Access := Root;
begin
   while Current /= null loop
      exit when Status /= Messages.Result.Success or else Is_Full (Sink);

      case Current.Kind is
         when Messages.AST.Text          =>
            Messages.Observability.Emit (Messages.Observability.Op_Text, "");
            Put_Text
              (Sink, To_String (Current.Text), Number_Text, Number_Active);

         when Messages.AST.Variable      =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit
                 (Messages.Observability.Op_Variable, Key);
               if Messages.Arguments.Has (Arguments, Key) then
                  Put (Sink, Messages.Arguments.Get (Arguments, Key));
               else
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               end if;
            end;

         when Messages.AST.Number        =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit
                 (Messages.Observability.Op_Variable, Key);
               if Messages.Arguments.Has (Arguments, Key) then
                  declare
                     Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
                     Last      : Natural;
                     Ok        : Boolean;
                     Format_Overflow : Boolean;
                  begin
                     I18N.Number_Format.Format_Into
                       (Value_Text => Messages.Arguments.Get (Arguments, Key),
                        Locale     => Locale,
                        Style      => To_String (Current.Currency_Code),
                        Target     => Formatted,
                        Last       => Last,
                        Ok         => Ok,
                        Overflow   => Format_Overflow);

                     if Format_Overflow then
                        Signal_Full (Sink);
                        Add_Runtime_Diagnostic
                          (Diagnostics, Messages.Result.Buffer_Overflow, Key);
                     elsif not Ok then
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     elsif Last > 0 then
                        Put (Sink, Formatted (1 .. Last));
                     end if;
                  end;
               else
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               end if;
            end;

         when Messages.AST.Date_Format | Messages.AST.Time_Format
            | Messages.AST.Date_Time_Format =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit
                 (Messages.Observability.Op_Variable, Key);
               if Messages.Arguments.Has (Arguments, Key) then
                  declare
                     Formatted : String (1 .. I18N.Date_Time_Format.Max_Formatted_Length);
                     Last      : Natural;
                     Ok        : Boolean;
                     Format_Overflow : Boolean;
                  begin
                     if Current.Kind = Messages.AST.Date_Format then
                        I18N.Date_Time_Format.Format_Date_Into
                          (Value_Text => Messages.Arguments.Get (Arguments, Key),
                           Locale     => Locale,
                           Style      => To_String (Current.Currency_Code),
                           Target     => Formatted,
                           Last       => Last,
                           Ok         => Ok,
                           Overflow   => Format_Overflow);
                     elsif Current.Kind = Messages.AST.Time_Format then
                        I18N.Date_Time_Format.Format_Time_Into
                          (Value_Text => Messages.Arguments.Get (Arguments, Key),
                           Locale     => Locale,
                           Style      => To_String (Current.Currency_Code),
                           Target     => Formatted,
                           Last       => Last,
                           Ok         => Ok,
                           Overflow   => Format_Overflow);
                     else
                        I18N.Date_Time_Format.Format_Date_Time_Into
                          (Value_Text => Messages.Arguments.Get (Arguments, Key),
                           Locale     => Locale,
                           Style      => To_String (Current.Currency_Code),
                           Target     => Formatted,
                           Last       => Last,
                           Ok         => Ok,
                           Overflow   => Format_Overflow);
                     end if;

                     if Format_Overflow then
                        Signal_Full (Sink);
                        Add_Runtime_Diagnostic
                          (Diagnostics, Messages.Result.Buffer_Overflow, Key);
                     elsif not Ok then
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     elsif Last > 0 then
                        Put (Sink, Formatted (1 .. Last));
                     end if;
                  end;
               else
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               end if;
            end;

         when Messages.AST.Currency      =>
            declare
               Key  : constant String := To_String (Current.Name);
               Code : constant String := To_String (Current.Currency_Code);
            begin
               Messages.Observability.Emit
                 (Messages.Observability.Op_Variable, Key);
               if Messages.Arguments.Has (Arguments, Key) then
                  declare
                     Formatted : String (1 .. I18N.Currency.Max_Formatted_Length);
                     Last      : Natural;
                     Ok        : Boolean;
                     Format_Overflow : Boolean;
                  begin
                     I18N.Currency.Format_Into
                       (Amount_Text   => Messages.Arguments.Get (Arguments, Key),
                        Currency_Code => Code,
                        Locale        => Locale,
                        Target        => Formatted,
                        Last          => Last,
                        Ok            => Ok,
                        Overflow      => Format_Overflow);

                     if Format_Overflow then
                        Signal_Full (Sink);
                        Add_Runtime_Diagnostic
                          (Diagnostics, Messages.Result.Buffer_Overflow, Key);
                     elsif not Ok then
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     elsif Last > 0 then
                        Put (Sink, Formatted (1 .. Last));
                     end if;
                  end;
               else
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               end if;
            end;

         when Messages.AST.Duration_Format | Messages.AST.Byte_Size_Format
            | Messages.AST.Unit_Format | Messages.AST.Relative_Time_Format
            | Messages.AST.List_Format =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit
                 (Messages.Observability.Op_Variable, Key);
               if Messages.Arguments.Has (Arguments, Key) then
                  declare
                     Formatted : String (1 .. Messages.Extra_Format.Max_Formatted_Length);
                     Last      : Natural;
                     Ok        : Boolean;
                     Format_Overflow : Boolean;
                  begin
                     Messages.Extra_Format.Format_Into
                       (Kind     => Extra_Kind_Of (Current.Kind),
                        Value    => Messages.Arguments.Get (Arguments, Key),
                        Locale   => Locale,
                        Option   => To_String (Current.Currency_Code),
                        Target   => Formatted,
                        Last     => Last,
                        Ok       => Ok,
                        Overflow => Format_Overflow);

                     if Format_Overflow then
                        Signal_Full (Sink);
                        Add_Runtime_Diagnostic
                          (Diagnostics, Messages.Result.Buffer_Overflow, Key);
                     elsif not Ok then
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     elsif Last > 0 then
                        Put (Sink, Formatted (1 .. Last));
                     end if;
                  end;
               else
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               end if;
            end;

         when Messages.AST.Plural        =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit (Messages.Observability.Op_Plural, Key);
               if not Messages.Arguments.Has (Arguments, Key) then
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               else
                  declare
                     Category : I18N.Plurals.Plural_Category;
                     Rendered : Unbounded_String;
                     Valid    : Boolean;
                  begin
                     --  Accept whole numbers and decimal quantities (the
                     --  latter via CLDR fractional operands).
                     Classify_Plural_Argument
                       (Raw      => Messages.Arguments.Get (Arguments, Key),
                        Locale   => Locale,
                        Offset   => Current.Plural_Offset,
                        Category => Category,
                        Rendered => Rendered,
                        Valid    => Valid);
                     if not Valid then
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     else
                        declare
                           Raw_Value : constant String :=
                             Messages.Arguments.Get (Arguments, Key);
                           Exact_Key : constant String :=
                             (if Is_Decimal_Integer (Raw_Value)
                              then Integer_Image_No_Leading_Space
                                     (Long_Long_Integer'Value (Raw_Value))
                              else "");
                           Branch : Messages.AST.Node_Access :=
                             (if Exact_Key'Length > 0
                              then Messages.AST.Branch_Body
                                     (Current.Plural_Exact, Exact_Key)
                              else null);
                        begin
                           if Branch = null then
                              Branch :=
                                (case Category is
                                   when I18N.Plurals.Zero =>
                                      Current.Plural_Zero,
                                   when I18N.Plurals.One =>
                                      Current.One,
                                   when I18N.Plurals.Two =>
                                      Current.Plural_Two,
                                   when I18N.Plurals.Few =>
                                      Current.Plural_Few,
                                   when I18N.Plurals.Many =>
                                      Current.Plural_Many,
                                   when I18N.Plurals.Other =>
                                      Current.Other);
                           end if;

                           if Branch = null then
                              Branch := Current.Other;
                           end if;

                           if Branch = null then
                              Status := Messages.Result.Formatting_Error;
                              Add_Runtime_Diagnostic
                                (Diagnostics, Status, Key);
                           else
                              Render_Sink
                                (Root          => Branch,
                                 Arguments     => Arguments,
                                 Sink          => Sink,
                                 Status        => Status,
                                 Diagnostics   => Diagnostics,
                                 Locale        => Locale,
                                 Number_Text   => To_String (Rendered),
                                 Number_Active => True);
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;

         when Messages.AST.Select_Node   =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit (Messages.Observability.Op_Select, Key);
               if not Messages.Arguments.Has (Arguments, Key) then
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               else
                  declare
                     Value   : constant String :=
                       Messages.Arguments.Get (Arguments, Key);
                     Matched : constant Boolean :=
                       Messages.AST.Has_Branch (Current.Branches, Value);
                     Branch  : constant Messages.AST.Node_Access :=
                       (if Matched
                        then Messages.AST.Branch_Body (Current.Branches, Value)
                        else
                          Messages.AST.Branch_Body (Current.Branches, "other"));
                  begin
                     if not Matched
                       and then not Messages.AST.Has_Branch
                                      (Current.Branches, "other")
                     then
                        Status := Messages.Result.Formatting_Error;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     elsif Branch /= null then
                        --  A present-but-empty branch (Branch = null)
                        --  renders as empty text with Success.
                        Render_Sink
                          (Root          => Branch,
                           Arguments     => Arguments,
                           Sink          => Sink,
                           Status        => Status,
                           Diagnostics   => Diagnostics,
                           Locale        => Locale,
                           Number_Text   => Number_Text,
                           Number_Active => Number_Active);
                     end if;
                  end;
               end if;
            end;

         when Messages.AST.SelectOrdinal =>
            declare
               Key : constant String := To_String (Current.Name);
            begin
               Messages.Observability.Emit (Messages.Observability.Op_Ordinal, Key);
               if not Messages.Arguments.Has (Arguments, Key) then
                  Status := Messages.Result.Missing_Argument;
                  Add_Runtime_Diagnostic (Diagnostics, Status, Key);
               else
                  declare
                     Raw : constant String :=
                       Messages.Arguments.Get (Arguments, Key);
                  begin
                     if not Is_Decimal_Integer (Raw) then
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     else
                        declare
                           Value    : constant Long_Long_Integer :=
                             Long_Long_Integer'Value (Raw);
                           Rendered : constant String :=
                             Integer_Image_No_Leading_Space (Value);
                           --  Select the ordinal branch by the locale's CLDR
                           --  ordinal category. Categories without a matching
                           --  branch fall back to other.
                           Branch   : Messages.AST.Node_Access :=
                             Messages.AST.Branch_Body
                               (Current.Ord_Exact, Rendered);
                        begin
                           if Branch = null then
                              case I18N.Plurals.Ordinal (Locale, Value) is
                                 when I18N.Plurals.Zero =>
                                    Branch := Current.Ord_Zero;
                                 when I18N.Plurals.One =>
                                    Branch := Current.Ord_One;
                                 when I18N.Plurals.Two =>
                                    Branch := Current.Ord_Two;
                                 when I18N.Plurals.Few =>
                                    Branch := Current.Ord_Few;
                                 when I18N.Plurals.Many =>
                                    Branch := Current.Ord_Many;
                                 when others =>
                                    Branch := Current.Ord_Other;
                              end case;
                           end if;

                           --  An absent category branch falls back to "other".
                           if Branch = null then
                              Branch := Current.Ord_Other;
                           end if;

                           if Branch = null then
                              Status := Messages.Result.Formatting_Error;
                              Add_Runtime_Diagnostic
                                (Diagnostics, Status, Key);
                           else
                              Render_Sink
                                (Root          => Branch,
                                 Arguments     => Arguments,
                                 Sink          => Sink,
                                 Status        => Status,
                                 Diagnostics   => Diagnostics,
                                 Locale        => Locale,
                                 Number_Text   => Rendered,
                                 Number_Active => True);
                           end if;
                        end;
                     end if;
                  exception
                     when Constraint_Error =>
                        Status := Messages.Result.Invalid_Argument;
                        Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end;
               end if;
            end;
      end case;

      Current := Current.Next;
   end loop;
end Render_Sink;
