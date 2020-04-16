module RegressionTest.Generator exposing
    ( RegressionTestGeneratorProgram
    , sandboxUpdate, update
    )

{-| Exposes a bunch of methods to generate test data for regression testing.


# Definition

@docs RegressionTestGeneratorProgram


# Test a program

@docs sandboxUpdate, update

-}

import Elm.CodeGen as CodeGen exposing (Import)
import Elm.Pretty as Pretty
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Random exposing (Generator)


type alias Flags =
    Encode.Value


type alias Configuration model msg =
    { modelGenerator : Generator model
    , messageGenerator : Generator msg
    , update : msg -> model -> ( model, Cmd msg )
    , encodeModel : model -> Encode.Value
    , encodeMessage : msg -> Encode.Value
    , outputPort : Encode.Value -> Cmd msg
    , numberOfTests : Int
    }


type alias ExternalConfiguration =
    { moduleName : String }


{-| Program used to generate test data for regression tests.
-}
type alias RegressionTestGeneratorProgram model msg =
    Program Flags (Model model msg) (Msg model msg)


type Model model msg
    = Model
        { configuration : Configuration model msg
        , state : State
        }


type State
    = Generating ExternalConfiguration
    | Generated
    | CannotDecodeFlags


type Msg model msg
    = ModelAndMessagesGenerated (List ( model, List msg ))
    | NoOp


type ExternalMessage
    = Success String
    | Error String


{-| Generate test data for a sandboxProgram, with the `update` function following the form `msg -> model -> model`.
-}
sandboxUpdate :
    { modelGenerator : Generator model
    , messageGenerator : Generator msg
    , update : msg -> model -> model
    , encodeModel : model -> Encode.Value
    , encodeMessage : msg -> Encode.Value
    , outputPort : Encode.Value -> Cmd msg
    , numberOfTests : Int
    }
    -> RegressionTestGeneratorProgram model msg
sandboxUpdate configuration =
    let
        standardizedConfiguration =
            { modelGenerator = configuration.modelGenerator
            , messageGenerator = configuration.messageGenerator
            , update = \msg model -> ( configuration.update msg model, Cmd.none )
            , encodeModel = configuration.encodeModel
            , encodeMessage = configuration.encodeMessage
            , outputPort = configuration.outputPort
            , numberOfTests = configuration.numberOfTests
            }
    in
    update standardizedConfiguration


{-| Generate test data for a standard program, with the `update` function following the form `msg -> model -> (model, Cmd msg)`.
-}
update :
    { modelGenerator : Generator model
    , messageGenerator : Generator msg
    , update : msg -> model -> ( model, Cmd msg )
    , encodeModel : model -> Encode.Value
    , encodeMessage : msg -> Encode.Value
    , outputPort : Encode.Value -> Cmd msg
    , numberOfTests : Int
    }
    -> RegressionTestGeneratorProgram model msg
update configuration =
    Platform.worker
        { init =
            \flags ->
                case Decode.decodeValue externalConfigurationDecoder flags of
                    Ok externalConfiguration ->
                        ( Model { state = Generating externalConfiguration, configuration = configuration }
                        , generateModelAndMessages configuration
                        )

                    Err _ ->
                        ( Model { state = CannotDecodeFlags, configuration = configuration }
                        , Error "Unable to decode flags, this can be caused by an invalid parameter"
                            |> encodeExternalMessage
                            |> configuration.outputPort
                            |> Cmd.map (always NoOp)
                        )
        , update = programUpdate
        , subscriptions = always Sub.none
        }


externalConfigurationDecoder : Decoder ExternalConfiguration
externalConfigurationDecoder =
    Decode.field "moduleName" Decode.string
        |> Decode.map ExternalConfiguration


generateModelAndMessages : Configuration model msg -> Cmd (Msg model msg)
generateModelAndMessages configuration =
    Random.int 3 50
        |> Random.andThen
            (\messagesCount ->
                Random.map2 Tuple.pair
                    configuration.modelGenerator
                    (Random.list messagesCount configuration.messageGenerator)
            )
        |> Random.list configuration.numberOfTests
        |> Random.generate ModelAndMessagesGenerated


programUpdate : Msg model msg -> Model model msg -> ( Model model msg, Cmd (Msg model msg) )
programUpdate msg (Model model) =
    case ( model.state, msg ) of
        ( Generating externalConfiguration, ModelAndMessagesGenerated inputsList ) ->
            let
                testDataList =
                    List.map (addFinalModel model.configuration) inputsList
            in
            ( Model { model | state = Generated }
            , toFile model.configuration externalConfiguration testDataList
                |> Success
                |> encodeExternalMessage
                |> model.configuration.outputPort
                |> Cmd.map (always NoOp)
            )

        ( _, ModelAndMessagesGenerated _ ) ->
            ( Model model, Cmd.none )

        ( _, NoOp ) ->
            ( Model model, Cmd.none )


addFinalModel : Configuration model msg -> ( model, List msg ) -> ( model, List msg, model )
addFinalModel configuration ( initialModel, msgList ) =
    let
        finalModel =
            List.foldl (\msg_ model_ -> configuration.update msg_ model_ |> Tuple.first) initialModel msgList
    in
    ( initialModel, msgList, finalModel )


toFile : Configuration model msg -> ExternalConfiguration -> List ( model, List msg, model ) -> String
toFile configuration externalConfiguration testDataList =
    let
        testData =
            List.map (toTestData configuration) testDataList
                |> CodeGen.list
                |> CodeGen.valDecl Nothing
                    (Just (CodeGen.listAnn (CodeGen.typeVar "UpdateFunctionTestData")))
                    "testData"

        updateFunctionTestDataImport =
            [ CodeGen.typeOrAliasExpose "UpdateFunctionTestData" ]
                |> CodeGen.exposeExplicit
                |> Just
                |> CodeGen.importStmt [ "RegressionTest", "Runner" ] Nothing
    in
    CodeGen.file (CodeGen.normalModule [ externalConfiguration.moduleName ] [])
        [ updateFunctionTestDataImport ]
        [ testData ]
        Nothing
        |> Pretty.pretty 120


toTestData : Configuration model msg -> ( model, List msg, model ) -> CodeGen.Expression
toTestData configuration ( initialModel, msgList, finalModel ) =
    let
        input =
            CodeGen.string (configuration.encodeModel initialModel |> Encode.encode 2)

        expectedOutput =
            CodeGen.string (configuration.encodeModel finalModel |> Encode.encode 2)

        messages =
            msgList
                |> List.map configuration.encodeMessage
                |> List.map (Encode.encode 2)
                |> List.map CodeGen.string
                |> CodeGen.list
    in
    CodeGen.record
        [ ( "initialModel", input )
        , ( "messages", messages )
        , ( "expectedOutput", expectedOutput )
        ]


encodeExternalMessage : ExternalMessage -> Encode.Value
encodeExternalMessage externalMessage =
    case externalMessage of
        Success fileContent ->
            Encode.object [ ( "type", Encode.string "success" ), ( "fileContent", Encode.string fileContent ) ]

        Error error ->
            Encode.object [ ( "type", Encode.string "error" ), ( "error", Encode.string error ) ]
