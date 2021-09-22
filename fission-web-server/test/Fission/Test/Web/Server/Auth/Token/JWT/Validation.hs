module Fission.Test.Web.Server.Auth.Token.JWT.Validation (spec) where

import qualified Data.Aeson                             as JSON
import           Network.HTTP.Client.TLS                as HTTP

import qualified Fission.Internal.Fixture.Bearer        as Fixture
import qualified Fission.Internal.Fixture.Bearer.Nested as Nested.Fixture

import           Fission.Web.Auth.Token.JWT.Types       as JWT
import qualified Fission.Web.Auth.Token.JWT.Validation  as JWT

import           Fission.Test.Web.Server.Prelude
import           Fission.User.DID.Types

import           Fission.Web.Auth.Token.JWT.Resolver    as Proof

spec :: Spec
spec =
  describe "JWT Validation" do
    -- return ()
    -- context "RSA 2048" do
      -- FIXME when we have a functioning real world case
      -- context "real world bearer token" do
      --   it "is valid" do
      --     JWT.pureChecks Fixture.rawContent Fixture.jwtRSA2048
      --       `shouldBe` Right Fixture.jwtRSA2048

      -- context "real world nested bearer token -- end to end" do
      --   it "is valid" do
      --     JWT.check Nested.Fixture.rawContent Nested.Fixture.jwtRSA2048
      --       `shouldBe` Nested.Fixture.InTimeBounds (pure $ Right Nested.Fixture.jwtRSA2048)

     describe "ION" do
       it "is valid 1" do   --    $ runIO do
         mgr    <- HTTP.newTlsManager
         result <- runIonic $ JWT.check mgr serverDID ionContent1 ionUCAN1
         result `shouldBe` Right ionUCAN1

       it "is valid 2" do   --    $ runIO do
         mgr    <- HTTP.newTlsManager
         result <- runIonic $ JWT.check mgr serverDID ionContent2 ionUCAN2
         result `shouldBe` Right ionUCAN2

       it "is valid 3" do   --    $ runIO do
         mgr    <- HTTP.newTlsManager
         result <- runIonic $ JWT.check mgr serverDID ionContent3 ionUCAN3
         result `shouldBe` Right ionUCAN2

ionContent1 :: JWT.RawContent
ionContent1 = JWT.RawContent "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzI0MDg5MTMsImZjdCI6W10sImlzcyI6ImRpZDppb246RWlBWFl0WU9zRlBYSzlyRXc5eGJMand3UG42VmotVWlvRnZSUlgxM01CSU5lUSIsIm5iZiI6MTYzMjMyMjQ1MywicHJmIjpudWxsLCJwdGMiOiJBUFBFTkQiLCJyc2MiOiIqIn0"

ionRaw1 :: ByteString
ionRaw1 = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzI0MDg5MTMsImZjdCI6W10sImlzcyI6ImRpZDppb246RWlBWFl0WU9zRlBYSzlyRXc5eGJMand3UG42VmotVWlvRnZSUlgxM01CSU5lUSIsIm5iZiI6MTYzMjMyMjQ1MywicHJmIjpudWxsLCJwdGMiOiJBUFBFTkQiLCJyc2MiOiIqIn0.oJ1S6j2nwSR3w6PC_pJnQ4FJjifq8SZKJx4kTcMkEGhghSkZdto5qNLpXQZ5UXGw8NPgdWw0AVszQVvxcdikCA"

ionUCAN1 :: JWT
Just ionUCAN1 = JSON.decodeStrict ("\""<> ionRaw1 <> "\"")

ionContent2 :: JWT.RawContent
ionContent2 = JWT.RawContent "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzI0MjI1ODcsImZjdCI6W10sImlzcyI6ImRpZDppb246RWlCMUthMkxSMjZPT3J0bUJqX0pjUnVSaGdHTm03R0dBRURIUkUtWUZSNHlqUSIsIm5iZiI6MTYzMjMzNjEyNywicHJmIjpudWxsLCJwdGMiOiJBUFBFTkQiLCJyc2MiOiIqIn0" -- "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzI0MTgyNDcsImZjdCI6W10sImlzcyI6ImRpZDppb246RWlCWTJkMGxuaWxEelZfVlB4VGYteWgtemNJamJ3bWNBY2gtYVZ2Q3MwX0NBZyIsIm5iZiI6MTYzMjMzMTc4NywicHJmIjpudWxsLCJwdGMiOiJBUFBFTkQiLCJyc2MiOiIqIn0"

ionRaw2 :: ByteString
ionRaw2 = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzI0MjI1ODcsImZjdCI6W10sImlzcyI6ImRpZDppb246RWlCMUthMkxSMjZPT3J0bUJqX0pjUnVSaGdHTm03R0dBRURIUkUtWUZSNHlqUSIsIm5iZiI6MTYzMjMzNjEyNywicHJmIjpudWxsLCJwdGMiOiJBUFBFTkQiLCJyc2MiOiIqIn0.iYUd8rT5DbCnVv631gjOmi6nqx10Td05YqLNII8l3NAatdqL5ZY-LTJLkd2iylzYEhqNy_y4rIQqjmxhj0A3AA" -- "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzI0MTgyNDcsImZjdCI6W10sImlzcyI6ImRpZDppb246RWlCWTJkMGxuaWxEelZfVlB4VGYteWgtemNJamJ3bWNBY2gtYVZ2Q3MwX0NBZyIsIm5iZiI6MTYzMjMzMTc4NywicHJmIjpudWxsLCJwdGMiOiJBUFBFTkQiLCJyc2MiOiIqIn0.hCqQ7AqQIAlJ-3NRHeqpe0wwQ1UEH2Bt9i0RpE1TcpJQV8bPBdve3C0tHu_sFWj4x8MdY5Hbf7O0-grtddeVCA"

ionUCAN2 :: JWT
Just ionUCAN2 = JSON.decodeStrict ("\""<> ionRaw2 <> "\"")

newtype IONIC a = IONIC { runIonic :: IO a }
  deriving newtype (Functor, Applicative, Monad, MonadIO, MonadTime)

instance Proof.Resolver IONIC where
  resolve _ = return . Left $ InvalidJWT "Should not hit this code path"

serverDID :: DID
Just serverDID = JSON.decode "\"did:key:z6MkgYGF3thn8k1Fv4p4dWXKtsXCnLH7q9yw4QgNPULDmDKB\""

ionContent3 :: JWT.RawContent
ionContent3 = JWT.RawContent "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzIzMzk5MDAsImZjdCI6W10sImlzcyI6ImRpZDprZXk6ejEzVjNTb2cyWWFVS2hkR0NtZ3g5VVp1VzFvMVNoRkpZYzZEdkdZZTdOVHQ2ODlOb0wyTXhLOEhCZjFkTUJEYnc2TmVLcWdIM2ZCS2o4VldGMm80MktpeHNyVjJEZUhGUVRvb2gzcUpGNzUydWFKeGt2Z0VkQ3U4ZEJCSkRjRVBQQkVKM21nRzVmUlN3NWR4U2RYTWhHdlR6Z3Y2d0xlWG9McUVDUEtubm1NYnJUWlJra0F4Y1B0S1NSMzhXbWJjTnNGR251SDNSdmJjOU5CcmliUVNqMlhwaHB0Z01NNGRWbVd2d3l2TlJtclg4Um5IcjhaNnJkSzFRamhNQlVhUDI4aUhBQXZXSlJ5eFJDVkRKYTJVekhrY3VHS25KZ0FrakNoY2pqWGo5eVRSb2ZkRk5lOUtOOTVzZ2lCRFBDZEFMNVRRdnpRY3lSYzNZTG9aekJ5czI5SFUzbUtyTGdLUFI5NEM1V0VYNkNwdnhRM0dya3g2dEg1bzllc3FucFg4RXdHTk1IcWltQVhldmZvOXROVnk1VG4iLCJuYmYiOjE2MzIzMzk4MTEsInByZiI6ImV5SmhiR2NpT2lKU1V6STFOaUlzSW5SNWNDSTZJa3BYVkNJc0luVmhkaUk2SWpFdU1DNHdJbjAuZXlKaGRXUWlPaUprYVdRNmEyVjVPbm94TTFZelUyOW5NbGxoVlV0b1pFZERiV2Q0T1ZWYWRWY3hiekZUYUVaS1dXTTJSSFpIV1dVM1RsUjBOamc1VG05TU1rMTRTemhJUW1ZeFpFMUNSR0ozTms1bFMzRm5TRE5tUWt0cU9GWlhSakp2TkRKTGFYaHpjbFl5UkdWSVJsRlViMjlvTTNGS1JqYzFNblZoU25ocmRtZEZaRU4xT0dSQ1FrcEVZMFZRVUVKRlNqTnRaMGMxWmxKVGR6VmtlRk5rV0Uxb1IzWlVlbWQyTm5kTVpWaHZUSEZGUTFCTGJtNXRUV0p5VkZwU2EydEJlR05RZEV0VFVqTTRWMjFpWTA1elJrZHVkVWd6VW5aaVl6bE9RbkpwWWxGVGFqSlljR2h3ZEdkTlRUUmtWbTFYZG5kNWRrNVNiWEpZT0ZKdVNISTRXalp5WkVzeFVXcG9UVUpWWVZBeU9HbElRVUYyVjBwU2VYaFNRMVpFU21FeVZYcElhMk4xUjB0dVNtZEJhMnBEYUdOcWFsaHFPWGxVVW05bVpFWk9aVGxMVGprMWMyZHBRa1JRUTJSQlREVlVVWFo2VVdONVVtTXpXVXh2V25wQ2VYTXlPVWhWTTIxTGNreG5TMUJTT1RSRE5WZEZXRFpEY0haNFVUTkhjbXQ0Tm5SSU5XODVaWE54Ym5CWU9FVjNSMDVOU0hGcGJVRllaWFptYnpsMFRsWjVOVlJ1SWl3aVpYaHdJam94TmpNeU16TTVPVEF3TENKbVkzUWlPbHRkTENKcGMzTWlPaUprYVdRNmEyVjVPbm94TTFZelUyOW5NbGxoVlV0b1pFZERiV2Q0T1ZWYWRWY3hiekZUYUVaS1dXTTJSSFpIV1dVM1RsUjBOamc1VG05TU1rMTRTemhJUW1ZeFpFMUNSR0ozTms1bFMzRm5TRE5tUWt0cU9GWlhSakp2TkRKTGFYaHpjbFl5UkdWSVJsRlViMjlvTTNGS1JqYzFNblZoU25ocmRtZEZaRU4xT0dSQ1FrcEVZMFZRVUVKRlNqTnRaMGMxWmxKVGR6VmtlRk5rV0Uxb1IzWlVlbWQyTm5kTVpWaHZUSEZGUTFCTGJtNXRUV0p5VkZwU2EydEJlR05RZEV0VFVqTTRWMjFpWTA1elJrZHVkVWd6VW5aaVl6bE9RbkpwWWxGVGFqSlljR2h3ZEdkTlRUUmtWbTFYZG5kNWRrNVNiWEpZT0ZKdVNISTRXalp5WkVzeFVXcG9UVUpWWVZBeU9HbElRVUYyVjBwU2VYaFNRMVpFU21FeVZYcElhMk4xUjB0dVNtZEJhMnBEYUdOcWFsaHFPWGxVVW05bVpFWk9aVGxMVGprMWMyZHBRa1JRUTJSQlREVlVVWFo2VVdONVVtTXpXVXh2V25wQ2VYTXlPVWhWTTIxTGNreG5TMUJTT1RSRE5WZEZXRFpEY0haNFVUTkhjbXQ0Tm5SSU5XODVaWE54Ym5CWU9FVjNSMDVOU0hGcGJVRllaWFptYnpsMFRsWjVOVlJ1SWl3aWJtSm1Jam94TmpNeU16TTVPREV3TENKd2NtWWlPaUpsZVVwb1lrZGphVTlwU2xOVmVra3hUbWxKYzBsdVVqVmpRMGsyU1d0d1dGWkRTWE5KYmxab1pHbEpOa2xxUlhWTlF6UjNTVzR3TG1WNVNtaGtWMUZwVDJsS2EyRlhVVFpoTWxZMVQyNXZlRTB4V1hwVk1qbHVUV3hzYUZaVmRHOWFSV1JFWWxka05FOVdWbUZrVm1ONFlucEdWR0ZGV2t0WFYwMHlVa2hhU0ZkWFZUTlViRkl3VG1wbk5WUnRPVTFOYXpFMFUzcG9TVkZ0V1hoYVJURkRVa2RLTTA1ck5XeFRNMFp1VTBST2JWRnJkSEZQUmxwWVVtcEtkazVFU2t4aFdHaDZZMnhaZVZKSFZrbFNiRVpWWWpJNWIwMHpSa3RTYW1NeFRXNVdhRk51YUhKa2JXUkdXa1ZPTVU5SFVrTlJhM0JGV1RCV1VWVkZTa1pUYWs1MFdqQmpNVnBzU2xSa2VsWnJaVVpPYTFkRk1XOVNNMXBWWlcxa01rNXVaRTFhVm1oMlZFaEdSbEV4UWt4aWJUVjBWRmRLZVZaR2NGTmhNblJDWlVkT1VXUkZkRlJWYWswMFZqSXhhVmt3TlhwU2EyUjFaRlZuZWxWdVdtbFplbXhQVVc1S2NGbHNSbFJoYWtwWlkwZG9kMlJIWkU1VVZGSnJWbTB4V0dSdVpEVmthelZUWWxoS1dVOUdTblZUU0VrMFYycGFlVnBGYzNoVlYzQnZWRlZLVmxsV1FYbFBSMnhKVVZWR01sWXdjRk5sV0doVFVURmFSVk50UlhsV1dIQkpZVEpPTVZJd2RIVlRiV1JDWVRKd1JHRkhUbkZoYkdoeFQxaHNWVlZ0T1cxYVJWcFBXbFJzVEZScWF6RmpNbVJ3VVd0U1VWRXlVa0pVUkZaVlZWaGFObFZYVGpWVmJVMTZWMVY0ZGxkdWNFTmxXRTE1VDFWb1ZrMHlNVXhqYTNodVV6RkNVMDlVVWtST1ZtUkdWMFJhUkdOSVdqUlZWRTVJWTIxME5FNXVVa2xPVnpnMVdsaE9lR0p1UWxsUFJWWXpVakExVGxOSVJuQmlWVVpaV2xoYWJXSjZiREJVYkZvMVRsWlNkVWxwZDJsYVdHaDNTV3B2ZWsxcVkzcE9hazE2VDFSbk1rMTVkMmxhYlU0d1NXcHdZbGhUZDJsaFdFNTZTV3B2YVZwSGJHdFBiV3gyWW1wd1JtRlZVak5VVmtaaFlqTktkMDR4V25aalJ6VkNaREJHVUdWVmREQmpNMlIzVlRJMVdWWXdXa2RPV0VFMVpHczFNV016UVhSVFZYQTJXa1p3YmtscGQybGliVXB0U1dwdmVFNXFUWGxOZWswMVQwUkJla3hEU25kamJWbHBUMjAxTVdKSGQzTkpia0l3V1hsSk5rbHNUbFpWUlZaVFdERldWRkpXU1dsTVEwcDVZekpOYVU5cFNYRkpiakF1WVc1eVdXMXZaVUV3V1ZCdlgxRkJlRzVPWVVaMlpGUjZUalZTVDAxblQxZHZTV3BWZGswNGVHRmhMVlpWWXpCWWJsTldVa2w2U1Y5VWVGbFFZemhXYUc5UFVqRkplbE5vWjBKSmVYWTJhRmx0YkZaak5uTmxORkZ0Y1hOUWRuZHpUMlJqWVVWRlp6VkxlR1ZyTjBGcVFWVXhNMnhIU0RscmFIUjRSVEYxYzNKUkxYaHpTVVp2ZUROR2FqUmtYM05sVG5wR2FsOWxaM0ZtVG1aRlJuTnlTMFZGVjJ4d01uUnNkM3A1TlVSa2RqZDRZamxqZFVjdFEweHdiamw2ZDBNNGJqbEZjVkZ6WDNVMmFHMDRRVFJGY2xaZmRrRXllV05sU1c1Vk9VdFFaRFpPY2pZNE5YQTJkMFJtZGpWTk9VVlBPQzFhTUdsaGNWOVVlbVZFUm1OcVV6UjJYekZvYTBGTFNHZHJXVU15Y201clZtaFdTM3AxVFdWbVExRktOUzFHU1V4U2EzbEpTRkJqVTFGRlZrUnpjRkJDV0MwemFYWjNjbVZEV1ZvelJucFJUMTkwWnpJM01HMVpNbkpEVFcxMk9ISkdiVmhCSWl3aWNIUmpJam9pUVZCUVJVNUVJaXdpY25Oaklqb2lLaUo5LlotRldhOVYtUHBxU1JEdXVSTHhyOExqNWMxb3JMRGc3YUIzbl9IVDhRNWE2MXlVNWJmTFdMV3QyTzEtTlFRVE9FMzVsUmlHS3RhVGxuS0F0WHZOSHRVODdOLU9QVk1VUzBFbWtlWTJ5MzA4VkV3OUdkeG96YzFMYmxBZFRrUGdwYmN5MFk3THRKTjAtM2JIQmQ0Wko5d0FCV0NGbmVvSWg1ZUxlQnRUUVNESXlUZkZHdGhkQklvd0FIN2pRYl9nX2E0WHFvYk5SaUd6Q0RZQmt5Q0JmUk1HSnYxZkJfd2pvd3BacVV0b1FHV3U0QU4xV01BdUJXWGtFcGZZOVNOLTEzbTRScmMxMDJJUllHTGJkbERMNlppMDBMMmJWWWxmQW5IdTF5dUgycWRSUU5OTUt6SWpQSjVacmE2d25JTGVMaENuX1VIa1JWczdCd1hEQ2dxLUdQQSIsInB0YyI6IkFQUEVORCIsInJzYyI6IioifQ"

ionRaw3 :: ByteString
ionRaw3 = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsInVhdiI6IjEuMC4wIn0.eyJhdWQiOiJkaWQ6a2V5OnpTdEVacHpTTXRUdDlrMnZzemd2Q3dGNGZMUVFTeUExNVc1QVE0ejNBUjZCeDRlRko1Y3JKRmJ1R3hLbWJtYTQiLCJleHAiOjE2MzIzMzk5MDAsImZjdCI6W10sImlzcyI6ImRpZDprZXk6ejEzVjNTb2cyWWFVS2hkR0NtZ3g5VVp1VzFvMVNoRkpZYzZEdkdZZTdOVHQ2ODlOb0wyTXhLOEhCZjFkTUJEYnc2TmVLcWdIM2ZCS2o4VldGMm80MktpeHNyVjJEZUhGUVRvb2gzcUpGNzUydWFKeGt2Z0VkQ3U4ZEJCSkRjRVBQQkVKM21nRzVmUlN3NWR4U2RYTWhHdlR6Z3Y2d0xlWG9McUVDUEtubm1NYnJUWlJra0F4Y1B0S1NSMzhXbWJjTnNGR251SDNSdmJjOU5CcmliUVNqMlhwaHB0Z01NNGRWbVd2d3l2TlJtclg4Um5IcjhaNnJkSzFRamhNQlVhUDI4aUhBQXZXSlJ5eFJDVkRKYTJVekhrY3VHS25KZ0FrakNoY2pqWGo5eVRSb2ZkRk5lOUtOOTVzZ2lCRFBDZEFMNVRRdnpRY3lSYzNZTG9aekJ5czI5SFUzbUtyTGdLUFI5NEM1V0VYNkNwdnhRM0dya3g2dEg1bzllc3FucFg4RXdHTk1IcWltQVhldmZvOXROVnk1VG4iLCJuYmYiOjE2MzIzMzk4MTEsInByZiI6ImV5SmhiR2NpT2lKU1V6STFOaUlzSW5SNWNDSTZJa3BYVkNJc0luVmhkaUk2SWpFdU1DNHdJbjAuZXlKaGRXUWlPaUprYVdRNmEyVjVPbm94TTFZelUyOW5NbGxoVlV0b1pFZERiV2Q0T1ZWYWRWY3hiekZUYUVaS1dXTTJSSFpIV1dVM1RsUjBOamc1VG05TU1rMTRTemhJUW1ZeFpFMUNSR0ozTms1bFMzRm5TRE5tUWt0cU9GWlhSakp2TkRKTGFYaHpjbFl5UkdWSVJsRlViMjlvTTNGS1JqYzFNblZoU25ocmRtZEZaRU4xT0dSQ1FrcEVZMFZRVUVKRlNqTnRaMGMxWmxKVGR6VmtlRk5rV0Uxb1IzWlVlbWQyTm5kTVpWaHZUSEZGUTFCTGJtNXRUV0p5VkZwU2EydEJlR05RZEV0VFVqTTRWMjFpWTA1elJrZHVkVWd6VW5aaVl6bE9RbkpwWWxGVGFqSlljR2h3ZEdkTlRUUmtWbTFYZG5kNWRrNVNiWEpZT0ZKdVNISTRXalp5WkVzeFVXcG9UVUpWWVZBeU9HbElRVUYyVjBwU2VYaFNRMVpFU21FeVZYcElhMk4xUjB0dVNtZEJhMnBEYUdOcWFsaHFPWGxVVW05bVpFWk9aVGxMVGprMWMyZHBRa1JRUTJSQlREVlVVWFo2VVdONVVtTXpXVXh2V25wQ2VYTXlPVWhWTTIxTGNreG5TMUJTT1RSRE5WZEZXRFpEY0haNFVUTkhjbXQ0Tm5SSU5XODVaWE54Ym5CWU9FVjNSMDVOU0hGcGJVRllaWFptYnpsMFRsWjVOVlJ1SWl3aVpYaHdJam94TmpNeU16TTVPVEF3TENKbVkzUWlPbHRkTENKcGMzTWlPaUprYVdRNmEyVjVPbm94TTFZelUyOW5NbGxoVlV0b1pFZERiV2Q0T1ZWYWRWY3hiekZUYUVaS1dXTTJSSFpIV1dVM1RsUjBOamc1VG05TU1rMTRTemhJUW1ZeFpFMUNSR0ozTms1bFMzRm5TRE5tUWt0cU9GWlhSakp2TkRKTGFYaHpjbFl5UkdWSVJsRlViMjlvTTNGS1JqYzFNblZoU25ocmRtZEZaRU4xT0dSQ1FrcEVZMFZRVUVKRlNqTnRaMGMxWmxKVGR6VmtlRk5rV0Uxb1IzWlVlbWQyTm5kTVpWaHZUSEZGUTFCTGJtNXRUV0p5VkZwU2EydEJlR05RZEV0VFVqTTRWMjFpWTA1elJrZHVkVWd6VW5aaVl6bE9RbkpwWWxGVGFqSlljR2h3ZEdkTlRUUmtWbTFYZG5kNWRrNVNiWEpZT0ZKdVNISTRXalp5WkVzeFVXcG9UVUpWWVZBeU9HbElRVUYyVjBwU2VYaFNRMVpFU21FeVZYcElhMk4xUjB0dVNtZEJhMnBEYUdOcWFsaHFPWGxVVW05bVpFWk9aVGxMVGprMWMyZHBRa1JRUTJSQlREVlVVWFo2VVdONVVtTXpXVXh2V25wQ2VYTXlPVWhWTTIxTGNreG5TMUJTT1RSRE5WZEZXRFpEY0haNFVUTkhjbXQ0Tm5SSU5XODVaWE54Ym5CWU9FVjNSMDVOU0hGcGJVRllaWFptYnpsMFRsWjVOVlJ1SWl3aWJtSm1Jam94TmpNeU16TTVPREV3TENKd2NtWWlPaUpsZVVwb1lrZGphVTlwU2xOVmVra3hUbWxKYzBsdVVqVmpRMGsyU1d0d1dGWkRTWE5KYmxab1pHbEpOa2xxUlhWTlF6UjNTVzR3TG1WNVNtaGtWMUZwVDJsS2EyRlhVVFpoTWxZMVQyNXZlRTB4V1hwVk1qbHVUV3hzYUZaVmRHOWFSV1JFWWxka05FOVdWbUZrVm1ONFlucEdWR0ZGV2t0WFYwMHlVa2hhU0ZkWFZUTlViRkl3VG1wbk5WUnRPVTFOYXpFMFUzcG9TVkZ0V1hoYVJURkRVa2RLTTA1ck5XeFRNMFp1VTBST2JWRnJkSEZQUmxwWVVtcEtkazVFU2t4aFdHaDZZMnhaZVZKSFZrbFNiRVpWWWpJNWIwMHpSa3RTYW1NeFRXNVdhRk51YUhKa2JXUkdXa1ZPTVU5SFVrTlJhM0JGV1RCV1VWVkZTa1pUYWs1MFdqQmpNVnBzU2xSa2VsWnJaVVpPYTFkRk1XOVNNMXBWWlcxa01rNXVaRTFhVm1oMlZFaEdSbEV4UWt4aWJUVjBWRmRLZVZaR2NGTmhNblJDWlVkT1VXUkZkRlJWYWswMFZqSXhhVmt3TlhwU2EyUjFaRlZuZWxWdVdtbFplbXhQVVc1S2NGbHNSbFJoYWtwWlkwZG9kMlJIWkU1VVZGSnJWbTB4V0dSdVpEVmthelZUWWxoS1dVOUdTblZUU0VrMFYycGFlVnBGYzNoVlYzQnZWRlZLVmxsV1FYbFBSMnhKVVZWR01sWXdjRk5sV0doVFVURmFSVk50UlhsV1dIQkpZVEpPTVZJd2RIVlRiV1JDWVRKd1JHRkhUbkZoYkdoeFQxaHNWVlZ0T1cxYVJWcFBXbFJzVEZScWF6RmpNbVJ3VVd0U1VWRXlVa0pVUkZaVlZWaGFObFZYVGpWVmJVMTZWMVY0ZGxkdWNFTmxXRTE1VDFWb1ZrMHlNVXhqYTNodVV6RkNVMDlVVWtST1ZtUkdWMFJhUkdOSVdqUlZWRTVJWTIxME5FNXVVa2xPVnpnMVdsaE9lR0p1UWxsUFJWWXpVakExVGxOSVJuQmlWVVpaV2xoYWJXSjZiREJVYkZvMVRsWlNkVWxwZDJsYVdHaDNTV3B2ZWsxcVkzcE9hazE2VDFSbk1rMTVkMmxhYlU0d1NXcHdZbGhUZDJsaFdFNTZTV3B2YVZwSGJHdFBiV3gyWW1wd1JtRlZVak5VVmtaaFlqTktkMDR4V25aalJ6VkNaREJHVUdWVmREQmpNMlIzVlRJMVdWWXdXa2RPV0VFMVpHczFNV016UVhSVFZYQTJXa1p3YmtscGQybGliVXB0U1dwdmVFNXFUWGxOZWswMVQwUkJla3hEU25kamJWbHBUMjAxTVdKSGQzTkpia0l3V1hsSk5rbHNUbFpWUlZaVFdERldWRkpXU1dsTVEwcDVZekpOYVU5cFNYRkpiakF1WVc1eVdXMXZaVUV3V1ZCdlgxRkJlRzVPWVVaMlpGUjZUalZTVDAxblQxZHZTV3BWZGswNGVHRmhMVlpWWXpCWWJsTldVa2w2U1Y5VWVGbFFZemhXYUc5UFVqRkplbE5vWjBKSmVYWTJhRmx0YkZaak5uTmxORkZ0Y1hOUWRuZHpUMlJqWVVWRlp6VkxlR1ZyTjBGcVFWVXhNMnhIU0RscmFIUjRSVEYxYzNKUkxYaHpTVVp2ZUROR2FqUmtYM05sVG5wR2FsOWxaM0ZtVG1aRlJuTnlTMFZGVjJ4d01uUnNkM3A1TlVSa2RqZDRZamxqZFVjdFEweHdiamw2ZDBNNGJqbEZjVkZ6WDNVMmFHMDRRVFJGY2xaZmRrRXllV05sU1c1Vk9VdFFaRFpPY2pZNE5YQTJkMFJtZGpWTk9VVlBPQzFhTUdsaGNWOVVlbVZFUm1OcVV6UjJYekZvYTBGTFNHZHJXVU15Y201clZtaFdTM3AxVFdWbVExRktOUzFHU1V4U2EzbEpTRkJqVTFGRlZrUnpjRkJDV0MwemFYWjNjbVZEV1ZvelJucFJUMTkwWnpJM01HMVpNbkpEVFcxMk9ISkdiVmhCSWl3aWNIUmpJam9pUVZCUVJVNUVJaXdpY25Oaklqb2lLaUo5LlotRldhOVYtUHBxU1JEdXVSTHhyOExqNWMxb3JMRGc3YUIzbl9IVDhRNWE2MXlVNWJmTFdMV3QyTzEtTlFRVE9FMzVsUmlHS3RhVGxuS0F0WHZOSHRVODdOLU9QVk1VUzBFbWtlWTJ5MzA4VkV3OUdkeG96YzFMYmxBZFRrUGdwYmN5MFk3THRKTjAtM2JIQmQ0Wko5d0FCV0NGbmVvSWg1ZUxlQnRUUVNESXlUZkZHdGhkQklvd0FIN2pRYl9nX2E0WHFvYk5SaUd6Q0RZQmt5Q0JmUk1HSnYxZkJfd2pvd3BacVV0b1FHV3U0QU4xV01BdUJXWGtFcGZZOVNOLTEzbTRScmMxMDJJUllHTGJkbERMNlppMDBMMmJWWWxmQW5IdTF5dUgycWRSUU5OTUt6SWpQSjVacmE2d25JTGVMaENuX1VIa1JWczdCd1hEQ2dxLUdQQSIsInB0YyI6IkFQUEVORCIsInJzYyI6IioifQ.hDX3cOx6aFYFTRTtsoW_VzbINpfrkByyrzk3Uyx2rllndO_l-790NXd-gsNAD8wow6dSgcQQmfXkhNRJ-6fkaWUyxE1V7FXYkCNhyckifxOYD7PZ4U4b3cHCFzyYJuTmzOQHPIr1K8Pbqe5HgU9-RgB09spXVdLN0r-z2dt2MRL1TXWkH3wspci5pHT2ByeofDnchiwOHaMA6pyOPM-CJhuXlRorUUujkqcgDm67_6tEJ1AHeY0UYeb8sTUhWi3GvgACmfyrhQ4Gjay_NxYWrzgNBUFTThPLZZf_55w_3rXhp421MZHyveuv_tN99KEJWdIEdg9Y1slu6eCfiNQENQ"

ionUCAN3 :: JWT
Just ionUCAN3 = JSON.decodeStrict ("\""<> ionRaw3 <> "\"")
