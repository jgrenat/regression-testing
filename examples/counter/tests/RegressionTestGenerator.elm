port module RegressionTestGenerator exposing (..)

import Counter exposing (init, update)
import Json.Encode as Encode
import Random exposing (Generator)
import RegressionTest.Generator as RegressionTest


port outputPort : Encode.Value -> Cmd msg


main =
    RegressionTest.sandboxUpdate
        { modelGenerator = initialModelGenerator
        , messageGenerator = messageGenerator
        , update = update
        , encodeModel = encodeModel
        , encodeMessage = encodeMessage
        , outputPort = outputPort
        , numberOfTests = 10
        }


initialModelGenerator : Generator Counter.Model
initialModelGenerator =
    Random.constant 0


encodeModel : Counter.Model -> Encode.Value
encodeModel model =
    Encode.int model

messageGenerator : Generator Counter.Msg
messageGenerator =
    Random.uniform Counter.Increment [Counter.Decrement]


encodeMessage : Counter.Msg -> Encode.Value
encodeMessage msg =
    case msg of
        Counter.Increment ->
            Encode.string "INCREMENT"

        Counter.Decrement ->
            Encode.string "DECREMENT"
