port module RegressionTestGenerator exposing (..)

import Game exposing (init, update)
import Json.Encode as Encode
import Random exposing (Generator)
import RegressionTest.Generator as RegressionTest


port outputPort : Encode.Value -> Cmd msg


main =
    RegressionTest.element
        { modelGenerator = initialModelGenerator
        , messageGenerator = messageGenerator
        , update = update
        , encodeModel = encodeModel
        , encodeMessage = encodeMessage
        , outputPort = outputPort
        , numberOfTests = 80
        }


initialModelGenerator : Generator Game.Model
initialModelGenerator =
    Random.constant (init |> Game.add "Chet" |> Game.add "cynthia")


encodeModel : Game.Model -> Encode.Value
encodeModel model =
    Encode.object
        [ ( "players", Encode.array Encode.string model.players )
        , ( "places", Encode.array Encode.int model.places )
        , ( "purses", Encode.array Encode.int model.purses )
        , ( "inPenaltyBox", Encode.array Encode.bool model.inPenaltyBox )
        , ( "popQuestions", Encode.list Encode.string model.popQuestions )
        , ( "scienceQuestions", Encode.list Encode.string model.scienceQuestions )
        , ( "sportsQuestions", Encode.list Encode.string model.sportsQuestions )
        , ( "rockQuestions", Encode.list Encode.string model.rockQuestions )
        , ( "currentPlayer", Encode.int model.currentPlayer )
        , ( "isGettingOutOfPenaltyBox", Encode.bool model.isGettingOutOfPenaltyBox )
        , ( "wasCorrectlyAnswered", Encode.bool model.wasCorrectlyAnswered )
        , ( "notAWinner", Encode.bool model.notAWinner )
        ]


messageGenerator : Generator Game.Msg
messageGenerator =
    Random.uniform
        (Random.map2 Game.DiceRolled (Random.int 1 6) (Random.uniform True [ False ]))
        [ Random.constant Game.NewTurn ]
        |> Random.andThen identity


encodeMessage : Game.Msg -> Encode.Value
encodeMessage msg =
    case msg of
        Game.DiceRolled rollValue didWin ->
            Encode.object [ ( "type", Encode.string "DiceRolled" ), ( "rollValue", Encode.int rollValue ), ( "didWin", Encode.bool didWin ) ]

        Game.NewTurn ->
            Encode.object [ ( "type", Encode.string "NewTurn" ) ]
