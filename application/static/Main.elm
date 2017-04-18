-- Read more about this program in the official Elm guide:
-- https://guide.elm-lang.org/architecture/effects/http.html

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder, field, succeed, map2, list, string, bool, dict, int, maybe, decodeString, map)
import Table

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
  }

type alias Model =
  { experimentlist : List Experiment
  , tableState : Table.State
  , query : String
  }


init : ( Model, Cmd Msg )
init =
  let
    model =
      { experimentlist = []
      , tableState = Table.initialSort "name"
      , query = ""
      }
  in
    ( model, fetchExperiments )

-- UPDATE

type Msg
  = Experiments
  | FetchList (Result Http.Error (List Experiment))
  | SetQuery String
  | SetTableState Table.State

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

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW
view : Model -> Html Msg
view { experimentlist, tableState, query } =
  let
    lowerQuery =
      String.toLower query

    acceptableExperiments =
      List.filter (String.contains lowerQuery << String.toLower << .name) experimentlist
  in
    div []
      [ h1 [] [ text "Available experiments" ]
      , input [ placeholder "Search by Name", onInput SetQuery ] []
      , Table.view config tableState acceptableExperiments
      ]

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
               ,input [type_ "hidden", name "min_sequence", value (toString exp.minseq)] []
               ,input [type_ "hidden", name "max_sequence", value (toString exp.maxseq)] []
               , button [type_ "submit"] [text "Download csv"] ]]

fetchExperiments: Cmd Msg
fetchExperiments =
  let
    url =
      "http://0.0.0.0:5000/experiments"
  in
    Http.send FetchList (Http.get url decodeListExperiments)

decodeExps =
  Json.Decode.map6 Experiment
    (field "name" Json.Decode.string)
    (field "excitation" Json.Decode.string)
    (field "damage" Json.Decode.string)
    (field "minseq" Json.Decode.int)
    (field "maxseq" Json.Decode.int)
    (field "range" Json.Decode.int)

decodeListExperiments =
  Json.Decode.list decodeExps