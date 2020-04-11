module RegressionTest.Runner exposing (TestData, application, document, element, sandbox)

import Expect exposing (Expectation)
import Json.Decode as Decode
import Test exposing (Test, describe, test)


type alias TestData =
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


sandbox :
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> model
    }
    -> List TestData
    -> Test
sandbox configuration testData =
    let
        standardizedConfiguration =
            { modelDecoder = configuration.modelDecoder
            , messageDecoder = configuration.messageDecoder
            , update = \msg model -> ( configuration.update msg model, Cmd.none )
            }
    in
    element standardizedConfiguration testData


element :
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> ( model, Cmd msg )
    }
    -> List TestData
    -> Test
element configuration testData =
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


document :
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> ( model, Cmd msg )
    }
    -> List TestData
    -> Test
document =
    element


application :
    { modelDecoder : Decode.Decoder model
    , messageDecoder : Decode.Decoder msg
    , update : msg -> model -> ( model, Cmd msg )
    }
    -> List TestData
    -> Test
application =
    element


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


decodeTestData : Configuration model msg -> TestData -> Result Decode.Error (ParsedTestData model msg)
decodeTestData configuration data =
    Result.map3
        ParsedTestData
        (Decode.decodeString configuration.modelDecoder data.initialModel)
        (List.map (Decode.decodeString configuration.messageDecoder) data.messages
            |> List.reverse
            |> List.foldl (Result.map2 (::)) (Ok [])
        )
        (Decode.decodeString configuration.modelDecoder data.expectedOutput)
