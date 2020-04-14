module RegressionTestRunner exposing (..)

import GeneratedRegressionTestData exposing (testData)
import RegressionTest.Runner as Runner
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)
import Game
import Test exposing (Test)

suite : Test
suite = Runner.update {modelDecoder = modelDecoder, messageDecoder = messageDecoder, update = Game.update} testData



modelDecoder : Decoder Game.Model
modelDecoder =
    Decode.succeed Game.Model
        |> required "players" (Decode.array Decode.string)
        |> required "places" (Decode.array Decode.int)
        |> required "purses" (Decode.array Decode.int)
        |> required "inPenaltyBox" (Decode.array Decode.bool)
        |> required "popQuestions" (Decode.list Decode.string)
        |> required "scienceQuestions" (Decode.list Decode.string)
        |> required "sportsQuestions" (Decode.list Decode.string)
        |> required "rockQuestions" (Decode.list Decode.string)
        |> required "currentPlayer" Decode.int
        |> required "isGettingOutOfPenaltyBox" Decode.bool
        |> required "wasCorrectlyAnswered" Decode.bool
        |> required "notAWinner" Decode.bool


messageDecoder : Decoder Game.Msg
messageDecoder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "DiceRolled" ->
                        Decode.map2 Game.DiceRolled (Decode.field "rollValue" Decode.int) (Decode.field "didWin" Decode.bool)

                    "NewTurn" ->
                        Decode.succeed Game.NewTurn

                    _ ->
                        Decode.fail "Unknown message"
            )
