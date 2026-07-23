with AUnit.Test_Suites;

package Messages.Runtime.Tests.Suite is

   --  Construct the complete ICU runtime AUnit suite.
   --
   --  @return Access value for the assembled test suite.
   function Suite
      return AUnit.Test_Suites.Access_Test_Suite;

end Messages.Runtime.Tests.Suite;
