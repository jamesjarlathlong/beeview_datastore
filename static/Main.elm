-- Read more about this program in the official Elm guide:
-- https://guide.elm-lang.org/architecture/effects/http.html

import Html exposing (..)
import Html.Attributes as H exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, succeed, map2, list, string, bool, dict, int, maybe, decodeString, map)
import Table
import Array
import Dict

main =
  Html.program
  { init = init
  , view = view
  , update = update
  , subscriptions = subscriptions
  }

-- MODEL
type alias Experiment = 
  { name : String
  , excitation: String
  , damage: String
  , minseq: Int
  , maxseq: Int
  , range: Int
  , userlength: String
  }
type alias FileLength = 
  { file: String
  , len: String
  }

type alias Model =
  { experimentlist : List Experiment
  , tableState : Table.State
  , query : String
  , downloadParams: Dict.Dict String String
  }


init : ( Model, Cmd Msg )
init =
  let
    model =
      { experimentlist = []
      , tableState = Table.initialSort "name"
      , query = ""
      , downloadParams = Dict.empty
      }
  in
    ( model, fetchExperiments )

-- UPDATE

type Msg
  = Experiments
  | FetchList (Result Http.Error (List Experiment))
  | SetQuery String
  | SetTableState Table.State
  | SelectSubrange FileLength

negate: Int -> Int -> Bool -> Bool
negate chosen index element =
    if chosen == index then not element else element

negateArray: Int -> Array.Array Bool -> Array.Array Bool
negateArray index arr = 
  Array.indexedMap (negate index) arr


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Experiments ->
      (model, fetchExperiments)

    FetchList (Ok experiments) ->
      ({ model | experimentlist = experiments }
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
      ({model|downloadParams = (Dict.insert newrange.file newrange.len) model.downloadParams}
      , Cmd.none
      )

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW
view : Model -> Html Msg
view { experimentlist, tableState, query, downloadParams} =
  let
    lowerQuery =
      String.toLower query
    withlengths = 
      List.map (zipExperimentLengths downloadParams) experimentlist
    acceptableExperiments =
      List.filter (String.contains lowerQuery << String.toLower << .name) withlengths
  in
    div [style [ ("font-family", "Arial") ]]
      [ h1 [] [ text "Available experiments" ]
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
config : Table.Config Experiment Msg
config =
  Table.config
    { toId = .name
    , toMsg = SetTableState
    , columns =
        [ Table.stringColumn "Name" .name
        , Table.intColumn "Length (s)" .range
        , Table.stringColumn "Damage" .damage
        , Table.stringColumn "Excitation" .excitation
        , inputLength
        , downloadColumn]
    }

downloadColumn : Table.Column Experiment Msg
downloadColumn =
  Table.veryCustomColumn
    { name = ""
    , viewData = viewDownload
    , sorter = Table.unsortable
    }

viewDownload : Experiment -> Table.HtmlDetails Msg
viewDownload exp =
  Table.HtmlDetails []
    [Html.form [action "/large.csv", method "post"] 
               [input [type_ "hidden", name "folder_name", value exp.name] []
               ,input [type_ "hidden", name "user_length", value (toString exp.userlength)] []
               ,input [type_ "hidden", name "min_sequence", value (toString exp.minseq)] []
               ,input [type_ "hidden", name "max_sequence", value (toString exp.maxseq)] []
               ,button [type_ "submit"] [text "Download csv"] ]]
inputLength : Table.Column Experiment Msg
inputLength =
  Table.veryCustomColumn
    { name = ""
    , viewData = viewInput
    , sorter = Table.unsortable
    }
applyFilelen: String -> String -> Msg
applyFilelen filename desiredlen =
  SelectSubrange (FileLength filename desiredlen)

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
      "http://lissbenchmark.us-east-1.elasticbeanstalk.com/experiments"
  in
    Http.send FetchList (Http.get url decodeListExperiments)

decodeExps =
  Json.Decode.map7 Experiment
    (field "name" Json.Decode.string)
    (field "excitation" Json.Decode.string)
    (field "damage" Json.Decode.string)
    (field "minseq" Json.Decode.int)
    (field "maxseq" Json.Decode.int)
    (field "range" Json.Decode.int)
    (field "userlength" Json.Decode.string)
decodeListExperiments =
  Json.Decode.list decodeExps