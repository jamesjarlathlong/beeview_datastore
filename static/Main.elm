-- https://guide.elm-lang.org/architecture/effects/http.html


module Main exposing (..)

import Html exposing (..)
import Html.Attributes as H exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, succeed, map2, list, string, bool, dict, int, maybe, decodeString, map)
import Table exposing (defaultCustomizations)
import Array
import Dict
import Html.Events.Extra exposing (targetValueIntParse)


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias RawExperiment =
    { name : String
    , excitation : String
    , damage : String
    , minseq : Int
    , maxseq : Int
    }


type alias Experiment =
    { name : String
    , excitation : String
    , damage : String
    , minseq : Int
    , maxseq : Int
    , range : Int
    , userstart : String
    , userfinish : String
    , userfreq : Int
    }


type alias FileLength =
    { file : String
    , len : String
    }


type alias FileFreq =
    { file : String
    , freq : Int
    }


type alias Model =
    { experimentlist : List Experiment
    , tableState : Table.State
    , query : String
    , lenParams : Dict.Dict String String
    , finishParams : Dict.Dict String String
    , freqParams : Dict.Dict String Int
    }


init : ( Model, Cmd Msg )
init =
    let
        model =
            { experimentlist = []
            , tableState = Table.initialSort "name"
            , query = ""
            , lenParams = Dict.empty
            , finishParams = Dict.empty
            , freqParams = Dict.empty
            }
    in
        ( model, fetchExperiments )



-- UPDATE


type Msg
    = Experiments
    | FetchList (Result Http.Error (List RawExperiment))
    | SetQuery String
    | SetTableState Table.State
    | SelectSubrange FileLength
    | SelectSubfinish FileLength
    | SelectFreq FileFreq


negate : Int -> Int -> Bool -> Bool
negate chosen index element =
    if chosen == index then
        not element
    else
        element


negateArray : Int -> Array.Array Bool -> Array.Array Bool
negateArray index arr =
    Array.indexedMap (negate index) arr


unraw : RawExperiment -> Experiment
unraw { name, excitation, damage, minseq, maxseq } =
    let
        range =
            (maxseq - minseq) // 1000

        inituserstart =
            (toString 0)

        inituserfinish =
            (toString range)
    in
        Experiment name excitation damage minseq maxseq range inituserstart inituserfinish 1000


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Experiments ->
            ( model, fetchExperiments )

        FetchList (Ok experiments) ->
            ( { model | experimentlist = (List.map unraw experiments) }
            , Cmd.none
            )

        FetchList (Err _) ->
            ( model, Cmd.none )

        SetQuery newQuery ->
            ( { model | query = newQuery }
            , Cmd.none
            )

        SetTableState newState ->
            ( { model | tableState = newState }
            , Cmd.none
            )

        SelectSubrange newrange ->
            ( { model | lenParams = (Dict.insert newrange.file newrange.len) model.lenParams }
            , Cmd.none
            )

        SelectSubfinish newfinish ->
            ( { model | finishParams = (Dict.insert newfinish.file newfinish.len) model.finishParams }
            , Cmd.none
            )

        SelectFreq newfreq ->
            ( { model | freqParams = (Dict.insert newfreq.file newfreq.freq) model.freqParams }
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg

view { experimentlist, tableState, query, lenParams, finishParams, freqParams } =
    let
        lowerQuery =
            String.toLower query

        withstart =
            List.map (zipExperimentLengths lenParams) experimentlist

        withfinish =
            List.map (zipExperimentFinish finishParams) withstart

        withlengthsfreqs =
            List.map (zipExperimentFreqs freqParams) withfinish

        acceptableExperiments =
            List.filter (String.contains lowerQuery << String.toLower << .name) withlengthsfreqs
    in
        div [ class "container" ]
            [ h1 [] [ text "Experiments" ]
            , input [ placeholder "Search by Name", onInput SetQuery ] []
            , Table.view config tableState acceptableExperiments
            ]


zipExperimentLengths : Dict.Dict String String -> Experiment -> Experiment
zipExperimentLengths userdefs exp =
    let
        lenInSecs =
            getExpLength exp.name userdefs
    in
        { exp | userstart = lenInSecs }


zipExperimentFinish : Dict.Dict String String -> Experiment -> Experiment
zipExperimentFinish userdefs exp =
    let
        lenInSecs =
            getExpLength exp.name userdefs
    in
        { exp | userfinish = lenInSecs }


getExpLength : String -> Dict.Dict String String -> String
getExpLength fname d =
    Dict.get fname d
        |> Maybe.withDefault "0"


zipExperimentFreqs : Dict.Dict String Int -> Experiment -> Experiment
zipExperimentFreqs userdefs exp =
    let
        freq =
            getExpFreq exp.name userdefs
    in
        { exp | userfreq = freq }


getExpFreq : String -> Dict.Dict String Int -> Int
getExpFreq fname d =
    Dict.get fname d
        |> Maybe.withDefault 100


config : Table.Config Experiment Msg
config =
    Table.customConfig
        { toId = .name
        , toMsg = SetTableState
        , columns =
            [ Table.stringColumn "Name" .name
            , outputLength
            , Table.stringColumn "Damage" .damage
            , Table.stringColumn "Excitation" .excitation
            , inputStart
            , inputFinish
            , inputFreq
            , downloadColumn
            ]
        , customizations =
            { defaultCustomizations | tableAttrs = toRowAttrs }
        }


toRowAttrs : List (Attribute Msg)
toRowAttrs =
    [ style []
    ]


downloadColumn : Table.Column Experiment Msg
downloadColumn =
    Table.veryCustomColumn
        { name = "Download"
        , viewData = viewDownload
        , sorter = Table.unsortable
        }


viewDownload : Experiment -> Table.HtmlDetails Msg
viewDownload exp =
    Table.HtmlDetails []
        [ Html.form [ action "/large.csv", method "post" ]
            [ input [ type_ "hidden", name "folder_name", value exp.name ] []
            , input [ type_ "hidden", name "userstart", value exp.userstart ] []
            , input [ type_ "hidden", name "userfinish", value exp.userfinish ] []
            , input [ type_ "hidden", name "min_sequence", value (toString exp.minseq) ] []
            , input [ type_ "hidden", name "max_sequence", value (toString exp.maxseq) ] []
            , input [ type_ "hidden", name "freq", value (toString exp.userfreq) ] []
            , button [ type_ "submit" ] [ text "Download csv" ]
            ]
        ]


inputName : Table.Column Experiment Msg
inputName =
    Table.veryCustomColumn
        { name = "Name"
        , viewData = viewName
        , sorter = Table.unsortable
        }


viewName : Experiment -> Table.HtmlDetails Msg
viewName exp =
    Table.HtmlDetails []
        [ div [] [ text exp.name ]
        ]


outputLength : Table.Column Experiment Msg
outputLength =
    Table.veryCustomColumn
        { name = "Length (s)"
        , viewData = viewLen
        , sorter = Table.increasingOrDecreasingBy .range
        }


viewLen : Experiment -> Table.HtmlDetails Msg
viewLen exp =
    Table.HtmlDetails [ style [ ( "width", "10%" ) ] ]
        [ div [] [ text (toString exp.range) ]
        ]


inputFreq : Table.Column Experiment Msg
inputFreq =
    Table.veryCustomColumn
        { name = "Desired frequency (Hz)"
        , viewData = viewFreq
        , sorter = Table.unsortable
        }


freqs =
    Dict.fromList ([ ( 0, 100 ), ( 1, 200 ), ( 2, 500 ), ( 3, 1000 ) ])


freqMap val =
    option [] [ text (toString val) ]


viewFreq : Experiment -> Table.HtmlDetails Msg
viewFreq exp =
    let
        selectEvent =
            on "change"
                (Json.Decode.map (applyFilefreq exp.name) targetValueIntParse)

        freqOptions =
            (List.map freqMap (Dict.values freqs))
    in
        Table.HtmlDetails [ style [ ( "width", "10%" ) ] ]
            [ select [ selectEvent ]
                freqOptions
            ]


inputStart : Table.Column Experiment Msg
inputStart =
    Table.veryCustomColumn
        { name = "Desired start second"
        , viewData = viewInputs
        , sorter = Table.unsortable
        }


inputFinish : Table.Column Experiment Msg
inputFinish =
    Table.veryCustomColumn
        { name = "Desired finish second"
        , viewData = viewInputf
        , sorter = Table.unsortable
        }


applyFilelen : String -> String -> Msg
applyFilelen filename desiredlen =
    SelectSubrange (FileLength filename desiredlen)


applyFilefin : String -> String -> Msg
applyFilefin filename desiredlen =
    SelectSubfinish (FileLength filename desiredlen)


applyFilefreq : String -> Int -> Msg
applyFilefreq filename desiredfreq =
    SelectFreq (FileFreq filename desiredfreq)


viewInputs : Experiment -> Table.HtmlDetails Msg
viewInputs exp =
    Table.HtmlDetails [ style [ ( "width", "10%" ) ] ]
        [ input
            [ type_ "number"
            , H.min "0"
            , H.max (toString exp.range)
            , onInput (applyFilelen exp.name)
            ]
            []
        ]


viewInputf : Experiment -> Table.HtmlDetails Msg
viewInputf exp =
    Table.HtmlDetails [ style [ ( "width", "10%" ) ] ]
        [ input
            [ type_ "number"
            , H.min "1"
            , H.max (toString exp.range)
            , onInput (applyFilefin exp.name)
            ]
            []
        ]


fetchExperiments : Cmd Msg
fetchExperiments =
  let
    url =
      "http://lissbenchmark.us-east-1.elasticbeanstalk.com/experiments"
  in
    Http.send FetchList (Http.get url decodeListExperiments)


decodeExps =
    Json.Decode.map5 RawExperiment
        (field "name" Json.Decode.string)
        (field "excitation" Json.Decode.string)
        (field "damage" Json.Decode.string)
        (field "minseq" Json.Decode.int)
        (field "maxseq" Json.Decode.int)


decodeListExperiments =
    Json.Decode.list decodeExps


zip : List a -> List b -> List ( a, b )
zip =
    List.map2 (,)
