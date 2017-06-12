-- https://guide.elm-lang.org/architecture/effects/http.html

import Html exposing (..)
import Html.Attributes as H exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, succeed, map2, list, string, bool, dict, int, maybe, decodeString, map)
<<<<<<< HEAD
import Table
import Array
import Dict
=======
import Table exposing (defaultCustomizations)
import Array
import Dict
import Html.Events.Extra exposing (targetValueIntParse)
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3

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
  , excitation: String
  , damage: String
  , minseq: Int
  , maxseq: Int
  }
type alias Experiment = 
  { name : String
  , excitation: String
  , damage: String
  , minseq: Int
  , maxseq: Int
  , range: Int
  , userlength: String
<<<<<<< HEAD
=======
  , userfreq:Int
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
  }
type alias FileLength = 
  { file: String
  , len: String
<<<<<<< HEAD
=======
  }
type alias FileFreq = 
  { file: String
  , freq: Int
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
  }

type alias Model =
  { experimentlist : List Experiment
  , tableState : Table.State
  , query : String
<<<<<<< HEAD
  , downloadParams: Dict.Dict String String
=======
  , lenParams: Dict.Dict String String
  , freqParams:  Dict.Dict String Int
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
  }


init : ( Model, Cmd Msg )
init =
  let
    model =
      { experimentlist = []
      , tableState = Table.initialSort "name"
      , query = ""
<<<<<<< HEAD
      , downloadParams = Dict.empty
=======
      , lenParams = Dict.empty
      , freqParams = Dict.empty
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
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
<<<<<<< HEAD
=======
  | SelectFreq FileFreq
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3

negate: Int -> Int -> Bool -> Bool
negate chosen index element =
    if chosen == index then not element else element

negateArray: Int -> Array.Array Bool -> Array.Array Bool
negateArray index arr = 
  Array.indexedMap (negate index) arr

<<<<<<< HEAD
=======
unraw: RawExperiment -> Experiment
unraw {name, excitation, damage, minseq, maxseq} =
  let 
    range = (maxseq-minseq)//1000
    inituserlength = (toString range)
  in Experiment name excitation damage minseq maxseq range inituserlength 1000
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Experiments ->
      (model, fetchExperiments)

    FetchList (Ok experiments) ->
      ({ model | experimentlist = (List.map unraw experiments) }
      , Cmd.none
      )

    FetchList (Err _ ) ->
      (model, Cmd.none)

    SetQuery newQuery ->
      ({ model | query = newQuery }
      , Cmd.none
      )

    SetTableState newState ->
      ({ model | tableState = newState }
      , Cmd.none
      )
    SelectSubrange newrange ->
<<<<<<< HEAD
      ({model|downloadParams = (Dict.insert newrange.file newrange.len) model.downloadParams}
      , Cmd.none
      )
=======
      ({model|lenParams = (Dict.insert newrange.file newrange.len) model.lenParams}
      , Cmd.none
      )
    SelectFreq newfreq ->
      ({model|freqParams = (Dict.insert newfreq.file newfreq.freq) model.freqParams}
      , Cmd.none
      )

>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW
view : Model -> Html Msg
<<<<<<< HEAD
view { experimentlist, tableState, query, downloadParams} =
=======
view { experimentlist, tableState, query, lenParams, freqParams} =
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
  let
    lowerQuery =
      String.toLower query
    withlengths = 
<<<<<<< HEAD
      List.map (zipExperimentLengths downloadParams) experimentlist
    acceptableExperiments =
      List.filter (String.contains lowerQuery << String.toLower << .name) withlengths
  in
    div [style [ ("font-family", "Arial") ]]
=======
      List.map (zipExperimentLengths lenParams) experimentlist
    withlengthsfreqs = 
      List.map (zipExperimentFreqs freqParams) withlengths
    acceptableExperiments =
      List.filter (String.contains lowerQuery << String.toLower << .name) withlengthsfreqs
  in
    div [class "container"]
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
      [ h1 [] [ text "Experiments" ]
      , input [ placeholder "Search by Name", onInput SetQuery ] []
      , Table.view config tableState acceptableExperiments
      ]
zipExperimentLengths: Dict.Dict String String -> Experiment -> Experiment
zipExperimentLengths userdefs exp =
  let lenInSecs = getExpLength exp.name userdefs
  in {exp|userlength = lenInSecs}

getExpLength: String -> Dict.Dict String String -> String
getExpLength fname d =
  Dict.get fname d
      |> Maybe.withDefault "0"
<<<<<<< HEAD
=======

zipExperimentFreqs: Dict.Dict String Int-> Experiment -> Experiment
zipExperimentFreqs userdefs exp =
  let freq = getExpFreq exp.name userdefs
  in {exp|userfreq = freq}

getExpFreq: String -> Dict.Dict String Int -> Int
getExpFreq fname d =
  Dict.get fname d
      |> Maybe.withDefault 100

>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
config : Table.Config Experiment Msg
config =
  Table.customConfig
    { toId = .name
    , toMsg = SetTableState
    , columns =
        [ Table.stringColumn "Name" .name
        , Table.intColumn "Length (s)" .range
        , Table.stringColumn "Damage" .damage
        , Table.stringColumn "Excitation" .excitation
        , inputLength
<<<<<<< HEAD
=======
        , inputFreq
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
        , downloadColumn]
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
    [Html.form [action "/large.csv", method "post"] 
               [input [type_ "hidden", name "folder_name", value exp.name] []
<<<<<<< HEAD
               ,input [type_ "hidden", name "user_length", value (toString exp.userlength)] []
               ,input [type_ "hidden", name "min_sequence", value (toString exp.minseq)] []
               ,input [type_ "hidden", name "max_sequence", value (toString exp.maxseq)] []
               ,button [type_ "submit"] [text "Download csv"] ]]
inputLength : Table.Column Experiment Msg
inputLength =
  Table.veryCustomColumn
    { name = ""
=======
               ,input [type_ "hidden", name "user_length", value exp.userlength] []
               ,input [type_ "hidden", name "min_sequence", value (toString exp.minseq)] []
               ,input [type_ "hidden", name "max_sequence", value (toString exp.maxseq)] []
               ,input [type_ "hidden", name "freq", value (toString exp.userfreq)] []
               ,button [type_ "submit"] [text "Download csv"] ]]

inputFreq : Table.Column Experiment Msg
inputFreq =
  Table.veryCustomColumn
    { name = "Desired frequency (Hz)"
    , viewData = viewFreq
    , sorter = Table.unsortable
    }
freqs = Dict.fromList([(0,100),(1,200),(2,500),(3,1000)])

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
    Table.HtmlDetails []
                    [select [selectEvent] 
                    freqOptions
                    ]

inputLength : Table.Column Experiment Msg
inputLength =
  Table.veryCustomColumn
    { name = "Desired length (s)"
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
    , viewData = viewInput
    , sorter = Table.unsortable
    }
applyFilelen: String -> String -> Msg
applyFilelen filename desiredlen =
  SelectSubrange (FileLength filename desiredlen)

<<<<<<< HEAD
=======
applyFilefreq: String -> Int -> Msg
applyFilefreq filename desiredfreq =
  SelectFreq (FileFreq filename desiredfreq)

>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
viewInput : Experiment -> Table.HtmlDetails Msg
viewInput exp =
  Table.HtmlDetails []
               [ input 
                  [ type_ "number"
                  , H.min "0"
                  , H.max (toString exp.range)
                  , onInput (applyFilelen exp.name)
                  ]
                  []
               ]
fetchExperiments: Cmd Msg
fetchExperiments =
  let
    url =
      "http://127.0.0.1:5000/experiments"
  in
    Http.send FetchList (Http.get url decodeListExperiments)

decodeExps =
<<<<<<< HEAD
  Json.Decode.map7 Experiment
=======
  Json.Decode.map5 RawExperiment
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
    (field "name" Json.Decode.string)
    (field "excitation" Json.Decode.string)
    (field "damage" Json.Decode.string)
    (field "minseq" Json.Decode.int)
    (field "maxseq" Json.Decode.int)
<<<<<<< HEAD
    (field "range" Json.Decode.int)
    (field "userlength" Json.Decode.string)
=======
>>>>>>> acd7742e4e046f7a04d827027873fbe5a1e8dce3
decodeListExperiments =
  Json.Decode.list decodeExps

zip : List a -> List b -> List (a, b)
zip = List.map2 (,)
