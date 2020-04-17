module RegressionTestRunner exposing (..)

import GeneratedRegressionTestData exposing (testData)
import RegressionTest.Runner as Runner
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)
import Counter
import Test exposing (Test)

suite : Test
suite =
    Runner.sandboxUpdate
        { modelDecoder = modelDecoder
        , messageDecoder = messageDecoder
        , update = Counter.update
        }
        testData



modelDecoder : Decoder Counter.Model
modelDecoder =
    Decode.int


messageDecoder : Decoder Counter.Msg
messageDecoder =
    Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "INCREMENT" ->
                        Decode.succeed Counter.Increment

                    "DECREMENT" ->
                        Decode.succeed Counter.Decrement

                    _ ->
                        Decode.fail "Unknown message"
            )
