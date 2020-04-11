module Game exposing (..)

import Array exposing (Array)
import Browser
import Html exposing (Html, text)
import Platform exposing (Program)
import Random exposing (Generator)
import Time


type alias Model =
    { players : Array String
    , places : Array Int
    , purses : Array Int
    , inPenaltyBox : Array Bool
    , popQuestions : List String
    , scienceQuestions : List String
    , sportsQuestions : List String
    , rockQuestions : List String
    , currentPlayer : Int
    , isGettingOutOfPenaltyBox : Bool
    , wasCorrectlyAnswered : Bool
    , notAWinner : Bool
    }


numberOfQuestions =
    5


isPlayable model =
    Array.length model.players >= 2


init : Model
init =
    let
        popQuestions =
            List.range 1 numberOfQuestions
                |> List.map (\index -> "Pop Question " ++ String.fromInt index)

        scienceQuestions =
            List.range 1 numberOfQuestions
                |> List.map (\index -> "Science Question " ++ String.fromInt index)

        sportsQuestions =
            List.range 1 numberOfQuestions
                |> List.map (\index -> "Sports Question " ++ String.fromInt index)

        rockQuestions =
            List.range 1 numberOfQuestions
                |> List.map createRockQuestion
    in
    { players = Array.empty
    , places = Array.empty
    , purses = Array.empty
    , inPenaltyBox = Array.empty
    , popQuestions = popQuestions
    , scienceQuestions = scienceQuestions
    , sportsQuestions = sportsQuestions
    , rockQuestions = rockQuestions
    , currentPlayer = 0
    , isGettingOutOfPenaltyBox = False
    , wasCorrectlyAnswered = False
    , notAWinner = True
    }


createRockQuestion : Int -> String
createRockQuestion index =
    "Rock Question " ++ String.fromInt index


didPlayerWin : Model -> Bool
didPlayerWin model =
    let
        playerName =
            Array.get model.currentPlayer model.players
                |> Maybe.withDefault ""
    in
    Array.get model.currentPlayer model.purses
        |> Maybe.map ((==) 6)
        |> Maybe.map
            (\hasWon ->
                let
                    _ =
                        Debug.log playerName
                            (if hasWon then
                                "has won"

                             else
                                "has not yet won"
                            )
                in
                hasWon
            )
        |> Maybe.withDefault False


getCurrentCategory : Model -> String
getCurrentCategory model =
    let
        place : Int
        place =
            Array.get model.currentPlayer model.places |> Maybe.withDefault 0
    in
    if place == 0 then
        "Pop"

    else if place == 4 then
        "Pop"

    else if place == 8 then
        "Pop"

    else if place == 1 then
        "Science"

    else if place == 5 then
        "Science"

    else if place == 9 then
        "Science"

    else if place == 2 then
        "Sports"

    else if place == 6 then
        "Sports"

    else if place == 10 then
        "Sports"

    else
        "Rock"


add : String -> Model -> Model
add playerName model =
    { model
        | players = Array.push playerName model.players
        , places = Array.push 0 model.places
        , purses = Array.push 0 model.purses
        , inPenaltyBox = Array.push False model.inPenaltyBox
    }


unshiftQuestion : Model -> ( String, Model )
unshiftQuestion model =
    if getCurrentCategory model == "Pop" then
        ( List.head model.popQuestions
            |> Maybe.withDefault ""
        , { model | popQuestions = List.tail model.popQuestions |> Maybe.withDefault [] }
        )

    else if getCurrentCategory model == "Science" then
        ( List.head model.scienceQuestions
            |> Maybe.withDefault ""
        , { model | scienceQuestions = List.tail model.scienceQuestions |> Maybe.withDefault [] }
        )

    else if getCurrentCategory model == "Sports" then
        ( List.head model.sportsQuestions
            |> Maybe.withDefault ""
        , { model | sportsQuestions = List.tail model.sportsQuestions |> Maybe.withDefault [] }
        )

    else
        ( List.head model.rockQuestions
            |> Maybe.withDefault ""
        , { model | rockQuestions = List.tail model.rockQuestions |> Maybe.withDefault [] }
        )


roll : Int -> Model -> Model
roll rollValue model =
    let
        ( question, newModel ) =
            unshiftQuestion model

        _ =
            Debug.log "Question" question

        inPenaltyBox =
            Array.get model.currentPlayer model.inPenaltyBox
                |> Maybe.withDefault False

        isGettingOutOfPenaltyBox =
            if inPenaltyBox then
                if modBy 2 rollValue /= 0 then
                    True

                else
                    False

            else
                False

        places =
            if not inPenaltyBox || isGettingOutOfPenaltyBox then
                Array.get model.currentPlayer model.places
                    |> Maybe.withDefault 0
                    |> (+) rollValue
                    |> (\newValue ->
                            if newValue > 11 then
                                newValue - 12

                            else
                                newValue
                       )
                    |> (\newValue -> Array.set model.currentPlayer newValue model.places)

            else
                model.places

        playersInPenaltyBox =
            Array.set model.currentPlayer (inPenaltyBox && not isGettingOutOfPenaltyBox) model.inPenaltyBox

        logs =
            [ "" ]
    in
    { newModel | inPenaltyBox = playersInPenaltyBox, places = places, isGettingOutOfPenaltyBox = isGettingOutOfPenaltyBox }


wasCorrectlyAnswered : Model -> Model
wasCorrectlyAnswered model =
    let
        playerName =
            Array.get model.currentPlayer model.players
                |> Maybe.withDefault ""

        _ =
            Debug.log (playerName ++ " answered") "correctly"

        isInPenaltyBox =
            Array.get model.currentPlayer model.inPenaltyBox
                |> Maybe.withDefault False
    in
    if isInPenaltyBox then
        if model.isGettingOutOfPenaltyBox then
            { model
                | purses =
                    Array.get model.currentPlayer model.purses
                        |> Maybe.withDefault 0
                        |> (+) 1
                        |> (\newValue -> Array.set model.currentPlayer newValue model.purses)
            }
                |> (\newModel ->
                        let
                            _ =
                                Debug.log (playerName ++ " score") (Array.get model.currentPlayer model.purses |> Maybe.withDefault 0)
                        in
                        { newModel
                            | notAWinner = not (didPlayerWin newModel)
                            , currentPlayer =
                                (newModel.currentPlayer + 1)
                                    |> modBy (Array.length newModel.players)
                        }
                   )

        else
            let
                _ =
                    Debug.log (playerName ++ " score") (Array.get model.currentPlayer model.purses |> Maybe.withDefault 0)
            in
            { model
                | currentPlayer =
                    model.currentPlayer
                        + 1
                        |> modBy (Array.length model.players)
                , notAWinner = True
            }

    else
        let
            _ =
                Debug.log (playerName ++ " score") ((Array.get model.currentPlayer model.purses |> Maybe.withDefault -1) + 1)
        in
        { model
            | purses =
                Array.get model.currentPlayer model.purses
                    |> Maybe.withDefault 0
                    |> (+) 1
                    |> (\newValue -> Array.set model.currentPlayer newValue model.purses)
        }
            |> (\newModel ->
                    { newModel
                        | notAWinner = not (didPlayerWin newModel)
                        , currentPlayer =
                            (newModel.currentPlayer + 1)
                                |> modBy (Array.length newModel.players)
                    }
               )


wrongAnswer : Model -> Model
wrongAnswer model =
    let
        playerName =
            Array.get model.currentPlayer model.players
                |> Maybe.withDefault ""

        _ =
            Debug.log (playerName ++ " answered") "wrongly"

        inPenaltyBox =
            Array.set model.currentPlayer True model.inPenaltyBox

        newPlayer =
            (model.currentPlayer + 1)
                |> modBy (Array.length model.players)
    in
    { model | inPenaltyBox = inPenaltyBox, wasCorrectlyAnswered = False, notAWinner = not (didPlayerWin model), currentPlayer = newPlayer }


diceGenerator : Generator Int
diceGenerator =
    Random.int 1 10


winGenerator : Generator Bool
winGenerator =
    Random.weighted ( 9, True ) [ ( 1, False ) ]


type Msg
    = DiceRolled Int Bool
    | NewTurn


view : Model -> Html msg
view model =
    text ""


main : Program () Model Msg
main =
    Browser.element
        { init = \() -> ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DiceRolled rollValue win ->
            let
                playerName =
                    Array.get model.currentPlayer model.players
                        |> Maybe.withDefault ""

                _ =
                    Debug.log ("––––––––––––––––––––––––––––––––––––––––––\n" ++ playerName ++ " rolled a ") rollValue
            in
            ( model
                |> roll rollValue
                |> (if win then
                        wasCorrectlyAnswered

                    else
                        wrongAnswer
                   )
            , Cmd.none
            )

        NewTurn ->
            ( model, letsRoll )


letsRoll : Cmd Msg
letsRoll =
    Random.map2 DiceRolled diceGenerator winGenerator
        |> Random.generate identity


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.notAWinner && isPlayable model then
        Time.every 1000 (always NewTurn)

    else
        Sub.none


initialModel : Model
initialModel =
    init
        |> add "Chet"
        |> add "Pat"
        |> add "Sue"
