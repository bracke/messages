with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with Messages.Validation;
with Messages.Errors;

package body Messages.Compiler is

   use Ada.Strings.Unbounded;
   use Messages.AST;
   use type Messages.Compiled.Op_Kind;

   function Next_Index
     (Build : Messages.Compiled.Builder)
      return Positive
   is
   begin
      return Messages.Compiled.Op_Count (Build) + 1;
   end Next_Index;

   procedure Patch
     (Build : in out Messages.Compiled.Builder;
      Index : Positive;
      Item  : Messages.Compiled.Op)
   is
   begin
      Messages.Compiled.Replace_Element (Build, Index, Item);
   end Patch;

   --  Emit a Stop_Branch op. Its End_Target is left 0 and back-patched later by
   --  Patch_Branch_Stops, which scans the branch's op range -- so the emitted
   --  index does not need to be returned to the caller.
   procedure Append_Stop
     (Build    : in out Messages.Compiled.Builder;
      Restores : Boolean)
   is
      Item : Messages.Compiled.Op;
   begin
      Item.Kind := Messages.Compiled.Stop_Branch;
      Item.Restores_Number_Context := Restores;
      Messages.Compiled.Append (Build, Item);
   end Append_Stop;

   procedure Compile_Nodes
     (Root        : Messages.AST.Node_Access;
      Build       : in out Messages.Compiled.Builder;
      Substitute  : Boolean);

   function Branch_Count
     (Branches : Messages.AST.Branch_Access)
      return Natural
   is
      Count   : Natural := 0;
      Current : Messages.AST.Branch_Access := Branches;
   begin
      while Current /= null loop
         Count := Count + 1;
         Current := Current.Next;
      end loop;

      return Count;
   end Branch_Count;

   function Select_Target_Count
     (Branches : Messages.AST.Branch_Access)
      return Natural
   is
      Count   : Natural := 0;
      Current : Messages.AST.Branch_Access := Branches;
   begin
      while Current /= null loop
         if To_String (Current.Name) /= "other" then
            Count := Count + 1;
         end if;

         Current := Current.Next;
      end loop;

      return Count;
   end Select_Target_Count;

   procedure Patch_Branch_Stops
     (Build : in out Messages.Compiled.Builder;
      First : Positive;
      Last  : Natural;
      Target : Positive)
   is
   begin
      if Last < First then
         return;
      end if;

      for Index in First .. Last loop
         declare
            Item : Messages.Compiled.Op := Messages.Compiled.Element (Build, Index);
         begin
            if Item.Kind = Messages.Compiled.Stop_Branch
              and then Item.End_Target = 0
            then
               Item.End_Target := Target;
               Patch (Build, Index, Item);
            end if;
         end;
      end loop;
   end Patch_Branch_Stops;

   --  Compile a plural- or ordinal-style category dispatch. Plural and ordinal
   --  differ only in the jump op kind, whether an offset applies, and which AST
   --  fields hold the branches -- so both feed this one routine.
   procedure Compile_Category_Branches
     (Node    : Messages.AST.Node;
      Build   : in out Messages.Compiled.Builder;
      Op_Kind : Messages.Compiled.Op_Kind;
      Offset  : Long_Long_Integer;
      Exact   : Messages.AST.Branch_Access;
      Zero    : Messages.AST.Node_Access;
      One     : Messages.AST.Node_Access;
      Two     : Messages.AST.Node_Access;
      Few     : Messages.AST.Node_Access;
      Many    : Messages.AST.Node_Access;
      Other   : Messages.AST.Node_Access)
   is
      Jump        : Messages.Compiled.Op;
      Jump_Index  : Positive;
      End_Index   : Positive;
      Exact_Count : constant Natural := Branch_Count (Exact);
   begin
      Jump.Kind := Op_Kind;
      Jump.Key := new String'(To_String (Node.Name));
      Jump.Plural_Offset := Offset;
      Messages.Compiled.Append (Build, Jump);
      Jump_Index := Messages.Compiled.Last_Index (Build);

      --  Only "other" is mandatory; absent category targets remain 0 so the
      --  renderer falls back to "other".
      if Exact_Count > 0 then
         declare
            Exact_Targets : Messages.Compiled.Exact_Target_Array (1 .. Exact_Count);
            Branch        : Messages.AST.Branch_Access := Exact;
            Index         : Positive := Exact_Targets'First;
         begin
            while Branch /= null loop
               Exact_Targets (Index).Value :=
                 Long_Long_Integer'Value (To_String (Branch.Name));
               Exact_Targets (Index).Target := Next_Index (Build);
               Compile_Nodes (Branch.Body_Root, Build, Substitute => True);
               Append_Stop (Build, Restores => True);
               Branch := Branch.Next;
               Index := Index + 1;
            end loop;

            Jump.Exact_Targets :=
              new Messages.Compiled.Exact_Target_Array'(Exact_Targets);
         end;
      end if;

      if Zero /= null then
         Jump.Zero_Target := Next_Index (Build);
         Compile_Nodes (Zero, Build, Substitute => True);
         Append_Stop (Build, Restores => True);
      end if;

      if One /= null then
         Jump.One_Target := Next_Index (Build);
         Compile_Nodes (One, Build, Substitute => True);
         Append_Stop (Build, Restores => True);
      end if;

      if Two /= null then
         Jump.Two_Target := Next_Index (Build);
         Compile_Nodes (Two, Build, Substitute => True);
         Append_Stop (Build, Restores => True);
      end if;

      if Few /= null then
         Jump.Few_Target := Next_Index (Build);
         Compile_Nodes (Few, Build, Substitute => True);
         Append_Stop (Build, Restores => True);
      end if;

      if Many /= null then
         Jump.Many_Target := Next_Index (Build);
         Compile_Nodes (Many, Build, Substitute => True);
         Append_Stop (Build, Restores => True);
      end if;

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Other, Build, Substitute => True);
      Append_Stop (Build, Restores => True);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Branch_Stops
        (Build  => Build,
         First  => Jump_Index + 1,
         Last   => End_Index - 1,
         Target => End_Index);
   end Compile_Category_Branches;

   procedure Compile_Plural
     (Node       : Messages.AST.Node;
      Build      : in out Messages.Compiled.Builder)
   is
   begin
      Compile_Category_Branches
        (Node    => Node,
         Build   => Build,
         Op_Kind => Messages.Compiled.Jump_Plural,
         Offset  => Node.Plural_Offset,
         Exact   => Node.Plural_Exact,
         Zero    => Node.Plural_Zero,
         One     => Node.One,
         Two     => Node.Plural_Two,
         Few     => Node.Plural_Few,
         Many    => Node.Plural_Many,
         Other   => Node.Other);
   end Compile_Plural;

   procedure Compile_Select
     (Node       : Messages.AST.Node;
      Build      : in out Messages.Compiled.Builder;
      Substitute : Boolean)
   is
      Jump         : Messages.Compiled.Op;
      Jump_Index   : Positive;
      End_Index    : Positive;
      Select_Count : constant Natural := Select_Target_Count (Node.Branches);
      Other_Body   : constant Messages.AST.Node_Access :=
        Messages.AST.Branch_Body (Node.Branches, "other");
   begin
      Jump.Kind := Messages.Compiled.Jump_Select;
      Jump.Key := new String'(To_String (Node.Name));
      Messages.Compiled.Append (Build, Jump);
      Jump_Index := Messages.Compiled.Last_Index (Build);

      if Select_Count > 0 then
         declare
            Select_Targets : Messages.Compiled.Select_Target_Array
              (1 .. Select_Count);
            Branch         : Messages.AST.Branch_Access := Node.Branches;
            Index          : Positive := Select_Targets'First;
         begin
            while Branch /= null loop
               declare
                  Name_Text : constant String := To_String (Branch.Name);
               begin
                  if Name_Text /= "other" then
                     Select_Targets (Index).Name := new String'(Name_Text);
                     Select_Targets (Index).Hash := Ada.Strings.Hash (Name_Text);
                     Select_Targets (Index).Target := Next_Index (Build);
                     Compile_Nodes (Branch.Body_Root, Build, Substitute);
                     Append_Stop (Build, Restores => False);
                     Index := Index + 1;
                  end if;
               end;

               Branch := Branch.Next;
            end loop;

            Jump.Select_Targets :=
              new Messages.Compiled.Select_Target_Array'(Select_Targets);
         end;
      end if;

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Other_Body, Build, Substitute);
      Append_Stop (Build, Restores => False);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Branch_Stops
        (Build  => Build,
         First  => Jump_Index + 1,
         Last   => End_Index - 1,
         Target => End_Index);
   end Compile_Select;

   procedure Compile_Ordinal
     (Node       : Messages.AST.Node;
      Build      : in out Messages.Compiled.Builder)
   is
   begin
      Compile_Category_Branches
        (Node    => Node,
         Build   => Build,
         Op_Kind => Messages.Compiled.Jump_Ordinal,
         Offset  => 0,
         Exact   => Node.Ord_Exact,
         Zero    => Node.Ord_Zero,
         One     => Node.Ord_One,
         Two     => Node.Ord_Two,
         Few     => Node.Ord_Few,
         Many    => Node.Ord_Many,
         Other   => Node.Ord_Other);
   end Compile_Ordinal;

   procedure Compile_Nodes
     (Root        : Messages.AST.Node_Access;
      Build       : in out Messages.Compiled.Builder;
      Substitute  : Boolean)
   is
      Current : Messages.AST.Node_Access := Root;
      Item    : Messages.Compiled.Op;
   begin
      while Current /= null loop
         case Current.Kind is
            when Messages.AST.Text =>
               Item := (Kind => Messages.Compiled.Text,
                        Text_Value => new String'(To_String (Current.Text)),
                        Substitute_Number_Sign => Substitute,
                        others => <>);
               Messages.Compiled.Append (Build, Item);

            when Messages.AST.Variable =>
               Item := (Kind => Messages.Compiled.Var,
                        Key => new String'(To_String (Current.Name)),
                        others => <>);
               Messages.Compiled.Append (Build, Item);

            when Messages.AST.Number =>
               Item := (Kind => Messages.Compiled.Number,
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        others => <>);
               Messages.Compiled.Append (Build, Item);

            when Messages.AST.Date_Format | Messages.AST.Time_Format
               | Messages.AST.Date_Time_Format =>
               Item := (Kind =>
                          (if Current.Kind = Messages.AST.Date_Format
                           then Messages.Compiled.Date_Format
                           elsif Current.Kind = Messages.AST.Time_Format
                           then Messages.Compiled.Time_Format
                           else Messages.Compiled.Date_Time_Format),
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        others => <>);
               Messages.Compiled.Append (Build, Item);

            when Messages.AST.Currency =>
               Item := (Kind => Messages.Compiled.Currency,
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        others => <>);
               Messages.Compiled.Append (Build, Item);

            when Messages.AST.Duration_Format | Messages.AST.Byte_Size_Format
               | Messages.AST.Unit_Format | Messages.AST.Relative_Time_Format
               | Messages.AST.List_Format =>
               Item := (Kind =>
                          (case Current.Kind is
                              when Messages.AST.Duration_Format =>
                                 Messages.Compiled.Duration_Format,
                              when Messages.AST.Byte_Size_Format =>
                                 Messages.Compiled.Byte_Size_Format,
                              when Messages.AST.Unit_Format =>
                                 Messages.Compiled.Unit_Format,
                              when Messages.AST.Relative_Time_Format =>
                                 Messages.Compiled.Relative_Time_Format,
                              when others =>
                                 Messages.Compiled.List_Format),
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        others => <>);
               Messages.Compiled.Append (Build, Item);

            when Messages.AST.Plural =>
               Compile_Plural (Current.all, Build);

            when Messages.AST.Select_Node =>
               Compile_Select (Current.all, Build, Substitute);

            when Messages.AST.SelectOrdinal =>
               Compile_Ordinal (Current.all, Build);
         end case;

         Current := Current.Next;
      end loop;
   end Compile_Nodes;

   function Compile
     (N : Messages.AST.Node_Access)
      return Messages.Compiled.Compiled_Message
   is
      Validation_Result : constant Messages.Errors.Result :=
        Messages.Validation.Validate (N);
      Build : Messages.Compiled.Builder;
   begin
      if not Validation_Result.Ok then
         raise Constraint_Error with "cannot compile invalid ICU AST";
      end if;

      Compile_Nodes (N, Build, Substitute => False);
      return Messages.Compiled.Freeze (Build);
   end Compile;

end Messages.Compiler;
