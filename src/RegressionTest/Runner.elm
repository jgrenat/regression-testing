module RegressionTest.Runner exposing
    ( UpdateFunctionTestData
    , sandboxUpdate, update
    )

{-| Exposes a bunch of methods to run tests based on generated test data.


# Definition

@docs UpdateFunctionTestData


# Test a program

@docs sandboxUpdate, update

-}

import Expect exposing (Expectation)
import Json.Decode as Decode
import Test exposing (Test, describe, test)


{-| Test data to test a `update` function
-}
type alias UpdateFunctionTestData =
    { initialModel : String
    , messages : List String
    , expectedOutput : String
    }


type alias Configuration model msg =
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> ( model, Cmd msg )
    }


type alias ParsedTestData model msg =
    { initialModel : model, messages : List msg, expectedOutput : model }


{-| Test the `update` function of a `sandbox` program, following the form `msg -> model -> model`, then compare the
results to the saved results.
-}
sandboxUpdate :
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> model
    }
    -> List UpdateFunctionTestData
    -> Test
sandboxUpdate configuration testData =
    let
        standardizedConfiguration =
            { modelDecoder = configuration.modelDecoder
            , messageDecoder = configuration.messageDecoder
            , update = \msg model -> ( configuration.update msg model, Cmd.none )
            }
    in
    update standardizedConfiguration testData


{-| Test a regular `update` function, following the form `msg -> model -> (model, Cmd msg)`, then compare the
results to the saved results.
The command part is not tested, only the model is kept.
-}
update :
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> ( model, Cmd msg )
    }
    -> List UpdateFunctionTestData
    -> Test
update configuration testData =
    List.map (decodeTestData configuration) testData
        |> List.indexedMap
            (\index result ->
                describe
                    ("Test #" ++ String.fromInt index)
                    [ test "has same final model than before" <|
                        \_ ->
                            case result of
                                Ok data ->
                                    toExpectation configuration data

                                Err _ ->
                                    Expect.fail "Invalid test data format"
                    ]
            )
        |> describe "Tests generated from previous program behaviour"


toExpectation : Configuration model msg -> ParsedTestData model msg -> Expectation
toExpectation configuration parsedTestData =
    let
        finalModel =
            List.foldl
                (\msg model -> configuration.update msg model |> Tuple.first)
                parsedTestData.initialModel
                parsedTestData.messages
    in
    Expect.equal parsedTestData.expectedOutput finalModel


decodeTestData : Configuration model msg -> UpdateFunctionTestData -> Result Decode.Error (ParsedTestData model msg)
decodeTestData configuration data =
    Result.map3
        ParsedTestData
        (Decode.decodeString configuration.modelDecoder data.initialModel)
        (List.map (Decode.decodeString configuration.messageDecoder) data.messages
            |> List.reverse
            |> List.foldl (Result.map2 (::)) (Ok [])
        )
        (Decode.decodeString configuration.modelDecoder data.expectedOutput)
