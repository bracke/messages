with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with Messages.AST;
with Messages.Compiler;
with Messages.Parser;
with Messages.Validation;

package body Messages.Cache is

   use Messages.Compiled;

   package Message_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Messages.Compiled.Message_Reference,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Cache model:
   --
   --  * Get_Or_Compile and Clear are initialization/build operations.
   --  * After initialization, Contains/Get/Compile_Count are plain read-only map
   --    accesses over immutable compiled-message references.
   --  * There is intentionally no protected object or mutex in Get.
   --
   --  Concurrent cache mutation is outside the execution contract. Shared
   --  runtimes bind Message_Reference handles before concurrent Render calls.
   Cache_Map : Message_Maps.Map;
   Compiles : Natural := 0;

   function Get_Or_Compile
     (Key     : String;
      Message : out Messages.Compiled.Compiled_Message)
      return Messages.Errors.Result
   is
      Root : Messages.AST.Node_Access := null;
   begin
      Messages.Compiled.Clear (Message);

      if Cache_Map.Contains (Key) then
         Messages.Compiled.Set_Reference (Message, Cache_Map.Element (Key));
         return Messages.Errors.Success ("");
      end if;

      begin
         Root := Messages.Parser.Parse (Key);
      exception
         when Messages.Parser.Unbalanced_Braces =>
            Messages.AST.Free (Root);
            return Messages.Errors.Failure (Messages.Errors.Unbalanced_Braces);
         when Messages.Parser.Parse_Error =>
            Messages.AST.Free (Root);
            return Messages.Errors.Failure (Messages.Errors.Parse_Error);
         when others =>
            Messages.AST.Free (Root);
            return Messages.Errors.Failure (Messages.Errors.Parse_Error);
      end;

      declare
         Validation_Result : constant Messages.Errors.Result :=
           Messages.Validation.Validate (Root);
      begin
         if not Validation_Result.Ok then
            Messages.AST.Free (Root);
            return Messages.Errors.Failure (Validation_Result.Error);
         end if;
      end;

      begin
         declare
            Compiled : constant Messages.Compiled.Compiled_Message :=
              Messages.Compiler.Compile (Root);
         begin
            Messages.Compiled.Set_Reference
              (Message, Messages.Compiled.Reference (Compiled));
         end;
      exception
         when others =>
            Messages.AST.Free (Root);
            return Messages.Errors.Failure (Messages.Errors.Parse_Error);
      end;

      Messages.AST.Free (Root);

      if not Cache_Map.Contains (Key) then
         Cache_Map.Insert (Key, Messages.Compiled.Reference (Message));
         Compiles := Compiles + 1;
      end if;

      Messages.Compiled.Set_Reference (Message, Cache_Map.Element (Key));
      return Messages.Errors.Success ("");
   end Get_Or_Compile;

   function Contains
     (Key : String)
      return Boolean
   is
   begin
      return Cache_Map.Contains (Key);
   end Contains;

   function Get
     (Key : String)
      return Messages.Compiled.Compiled_Message
   is
   begin
      return Message : Messages.Compiled.Compiled_Message do
         Messages.Compiled.Set_Reference (Message, Cache_Map.Element (Key));
      end return;
   end Get;

   procedure Clear is
   begin
      Cache_Map.Clear;
      Compiles := 0;
   end Clear;

   function Compile_Count return Natural is
   begin
      return Compiles;
   end Compile_Count;

end Messages.Cache;
