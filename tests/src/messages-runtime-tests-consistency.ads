with AUnit;
with AUnit.Test_Cases;

package Messages.Runtime.Tests.Consistency is

   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   --  Return the AUnit display name for this test case.
   --
   --  @param T Test case instance to identify.
   --  @return AUnit display name for the catalog consistency tests.
   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String;

   --  Register catalog consistency tests with AUnit.
   --
   --  @param T Test case instance to populate.
   overriding procedure Register_Tests
     (T : in out Test_Case);

end Messages.Runtime.Tests.Consistency;
