with Messages.AST; use Messages.AST;
with I18N.Currency;
with Messages.Extra_Format;
with Ada.Strings.Unbounded;

package body Messages.Validation is

   use Ada.Strings.Unbounded;

   function Is_Identifier_Character
     (C : Character)
      return Boolean
   is
   begin
      return
        (C in 'A' .. 'Z')
        or else (C in 'a' .. 'z')
        or else (C in '0' .. '9')
        or else C = '_'
        or else C = '-';
   end Is_Identifier_Character;

   function Is_Valid_Identifier
     (Text : String)
      return Boolean
   is
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for C of Text loop
         if not Is_Identifier_Character (C) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid_Identifier;

   function Validate_Nodes
     (N : Messages.AST.Node_Access)
      return Messages.Errors.Result;

   function Validate_Branch
     (N : Messages.AST.Node_Access)
      return Messages.Errors.Result
   is
   begin
      if N = null then
         return Messages.Errors.Failure (Messages.Errors.Missing_Branch);
      end if;

      return Validate_Nodes (N);
   end Validate_Branch;

   function Validate_Exact_Branches
     (Branches : Messages.AST.Branch_Access)
      return Messages.Errors.Result
   is
      Branch : Messages.AST.Branch_Access := Branches;
   begin
      while Branch /= null loop
         if Branch.Body_Root /= null then
            declare
               Branch_Result : constant Messages.Errors.Result :=
                 Validate_Nodes (Branch.Body_Root);
            begin
               if not Branch_Result.Ok then
                  return Branch_Result;
               end if;
            end;
         end if;

         Branch := Branch.Next;
      end loop;

      return Messages.Errors.Success ("");
   end Validate_Exact_Branches;

   function Validate_Nodes
     (N : Messages.AST.Node_Access)
      return Messages.Errors.Result
   is
      Current : Messages.AST.Node_Access := N;
   begin
      while Current /= null loop
         case Current.Kind is
            when Messages.AST.Text =>
               null;

            when Messages.AST.Variable =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

            when Messages.AST.Number =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

            when Messages.AST.Date_Format | Messages.AST.Time_Format
               | Messages.AST.Date_Time_Format =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

            when Messages.AST.Currency =>
               if not Is_Valid_Identifier (To_String (Current.Name))
                 or else not I18N.Currency.Is_Valid_Code
                               (To_String (Current.Currency_Code))
               then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

            when Messages.AST.Duration_Format | Messages.AST.Byte_Size_Format
               | Messages.AST.Unit_Format | Messages.AST.Relative_Time_Format
               | Messages.AST.List_Format =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               elsif Current.Kind = Messages.AST.Unit_Format
                 and then not Messages.Extra_Format.Is_Valid_Option
                                (Messages.Extra_Format.Unit,
                                 To_String (Current.Currency_Code))
               then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               elsif Current.Kind = Messages.AST.Relative_Time_Format
                 and then not Messages.Extra_Format.Is_Valid_Option
                                (Messages.Extra_Format.Relative_Time,
                                 To_String (Current.Currency_Code))
               then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               elsif Current.Kind = Messages.AST.List_Format
                 and then not Messages.Extra_Format.Is_Valid_Option
                                (Messages.Extra_Format.List,
                                 To_String (Current.Currency_Code))
               then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

            when Messages.AST.Plural =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               elsif Current.Plural_Offset < 0 then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

               --  Only "other" is mandatory. Absent category branches are
               --  valid and fall back to "other" at render time.
               if Current.Plural_Zero /= null then
                  declare
                     Zero_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Plural_Zero);
                  begin
                     if not Zero_Result.Ok then
                        return Zero_Result;
                     end if;
                  end;
               end if;

               if Current.One /= null then
                  declare
                     One_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.One);
                  begin
                     if not One_Result.Ok then
                        return One_Result;
                     end if;
                  end;
               end if;

               if Current.Plural_Two /= null then
                  declare
                     Two_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Plural_Two);
                  begin
                     if not Two_Result.Ok then
                        return Two_Result;
                     end if;
                  end;
               end if;

               if Current.Plural_Few /= null then
                  declare
                     Few_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Plural_Few);
                  begin
                     if not Few_Result.Ok then
                        return Few_Result;
                     end if;
                  end;
               end if;

               if Current.Plural_Many /= null then
                  declare
                     Many_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Plural_Many);
                  begin
                     if not Many_Result.Ok then
                        return Many_Result;
                     end if;
                  end;
               end if;

               declare
                  Other_Result : constant Messages.Errors.Result :=
                    Validate_Branch (Current.Other);
               begin
                  if not Other_Result.Ok then
                     return Other_Result;
                  end if;
               end;

               declare
                  Exact_Result : constant Messages.Errors.Result :=
                    Validate_Exact_Branches (Current.Plural_Exact);
               begin
                  if not Exact_Result.Ok then
                     return Exact_Result;
                  end if;
               end;

            when Messages.AST.Select_Node =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

               --  Each named branch must use a valid identifier and contain a
               --  structurally valid body. Branch bodies may be empty (a
               --  present-but-empty branch).
               declare
                  Branch : Messages.AST.Branch_Access := Current.Branches;
               begin
                  while Branch /= null loop
                     if not Is_Valid_Identifier (To_String (Branch.Name)) then
                        return
                          Messages.Errors.Failure (Messages.Errors.Validation_Error);
                     end if;

                     if Branch.Body_Root /= null then
                        declare
                           Branch_Result : constant Messages.Errors.Result :=
                             Validate_Nodes (Branch.Body_Root);
                        begin
                           if not Branch_Result.Ok then
                              return Branch_Result;
                           end if;
                        end;
                     end if;

                     Branch := Branch.Next;
                  end loop;
               end;

               --  The mandatory fallback branch named "other" must be present.
               if not Messages.AST.Has_Branch (Current.Branches, "other") then
                  return Messages.Errors.Failure (Messages.Errors.Missing_Branch);
               end if;

            when Messages.AST.SelectOrdinal =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return Messages.Errors.Failure (Messages.Errors.Validation_Error);
               end if;

               --  Only "other" is mandatory. Absent category branches are
               --  valid and fall back to "other" at render time.
               if Current.Ord_Zero /= null then
                  declare
                     Zero_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Ord_Zero);
                  begin
                     if not Zero_Result.Ok then
                        return Zero_Result;
                     end if;
                  end;
               end if;

               if Current.Ord_One /= null then
                  declare
                     One_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Ord_One);
                  begin
                     if not One_Result.Ok then
                        return One_Result;
                     end if;
                  end;
               end if;

               if Current.Ord_Two /= null then
                  declare
                     Two_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Ord_Two);
                  begin
                     if not Two_Result.Ok then
                        return Two_Result;
                     end if;
                  end;
               end if;

               if Current.Ord_Few /= null then
                  declare
                     Few_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Ord_Few);
                  begin
                     if not Few_Result.Ok then
                        return Few_Result;
                     end if;
                  end;
               end if;

               if Current.Ord_Many /= null then
                  declare
                     Many_Result : constant Messages.Errors.Result :=
                       Validate_Nodes (Current.Ord_Many);
                  begin
                     if not Many_Result.Ok then
                        return Many_Result;
                     end if;
                  end;
               end if;

               declare
                  Other_Result : constant Messages.Errors.Result :=
                    Validate_Branch (Current.Ord_Other);
               begin
                  if not Other_Result.Ok then
                     return Other_Result;
                  end if;
               end;

               declare
                  Exact_Result : constant Messages.Errors.Result :=
                    Validate_Exact_Branches (Current.Ord_Exact);
               begin
                  if not Exact_Result.Ok then
                     return Exact_Result;
                  end if;
               end;
         end case;

         Current := Current.Next;
      end loop;

      return Messages.Errors.Success ("");
   end Validate_Nodes;

   function Validate
     (N : Messages.AST.Node_Access)
      return Messages.Errors.Result
   is
   begin
      return Validate_Nodes (N);
   exception
      when others =>
         return Messages.Errors.Failure (Messages.Errors.Validation_Error);
   end Validate;

end Messages.Validation;
