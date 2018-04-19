module Main exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes exposing (..)
import Json.Decode exposing (..)
import List exposing (..)
import Json.Decode as Json


type alias Row =
    List Cell


type alias Cell =
    { cell : String, color : String }


type alias Table =
    List Row


type Mode
    = DrawMode
    | SelectMode


type alias CellPos =
    { row : Maybe String, cell : Maybe String }


type alias CellPos2 =
    Maybe ( String, String )


type alias Model =
    { table : Table
    , drawing : Bool
    , showGrid : Bool
    , mode : Mode
    , char : String
    , color : String
    }


type Msg
    = StartDrawing
    | StopDrawing
    | Draw CellPos
    | SetColor String
    | SetMode Mode
    | Clear
    | ChangeChar String


makeTable : Int -> Int -> Table
makeTable rows cells =
    repeat rows (repeat cells (Cell " " "black"))


initModel : Model
initModel =
    { table = makeTable 30 80
    , mode = DrawMode
    , drawing = False
    , showGrid = True
    , char = "$"
    , color = "#ff2600"
    }


mapAt : (a -> a) -> Int -> List a -> List a
mapAt f index =
    indexedMap
        (\i x ->
            if i == index then
                f x
            else
                x
        )


updateTable : Int -> Int -> String -> String -> Table -> Table
updateTable row cell char color table =
    mapAt
        (mapAt (\c -> { color = color, cell = char }) cell)
        row
        table


chunk : Int -> String -> List String
chunk n str =
    if String.length str > 0 then
        [ String.left n str ] ++ (chunk n str)
    else
        []


update : Msg -> Model -> Model
update msg model =
    case msg of
        Clear ->
            { model | table = initModel.table }

        ChangeChar char ->
            { model | char = char }

        SetColor color ->
            { model | color = color }

        SetMode mode ->
            { model | mode = mode }

        StartDrawing ->
            { model | drawing = True }

        StopDrawing ->
            { model | drawing = False }

        Draw pos ->
            if (model.drawing && model.mode == DrawMode) then
                case pos.row of
                    Just row ->
                        case pos.cell of
                            Just cell ->
                                { model
                                    | table =
                                        updateTable
                                            (Result.withDefault 0 (String.toInt row))
                                            (Result.withDefault 0 (String.toInt cell))
                                            model.char
                                            model.color
                                            model.table
                                }

                            _ ->
                                model

                    _ ->
                        model
            else
                model


decodePos : Decoder CellPos
decodePos =
    field "target" <|
        Json.map2 CellPos
            (at [ "dataset", "row" ] (nullable string))
            (at [ "dataset", "cell" ] (nullable string))


cell : Int -> Int -> Cell -> Html Msg
cell row cellN cell =
    div
        [ class "cell"
        , style [ ( "color", cell.color ) ]
        , attribute "data-row" (toString row)
        , attribute "data-cell" (toString cellN)
        ]
        [ text cell.cell ]


row : Int -> Row -> Html Msg
row rowN =
    indexedMap (cell rowN) >> div [ class "row" ]


table : Model -> Html Msg
table model =
    div
        [ classList
            [ ( "table", True )
            , ( "table--with-grid", model.showGrid )
            , ( "table--selectable", model.mode == SelectMode )
            ]
        , onMouseDown StartDrawing
        , onMouseUp StopDrawing
        , onMouseLeave StopDrawing
        , on "mousemove" (Json.map Draw decodePos)
        ]
        (case model.mode of
            DrawMode ->
                .table model |> indexedMap row

            SelectMode ->
                textTable model
        )


textCell { cell, color } =
    span [ class "cell cell--selectable", style [ ( "color", color ) ] ] [ text cell ]


textTable =
    .table
        >> List.map (\row -> List.map textCell row)
        >> intersperse ([ br [] [] ])
        >> foldr (++) []


toolItem : Bool -> List (Html msg) -> Html msg
toolItem active =
    li [ classList [ ( "tool-item", True ), ( "tool-item--active", active ) ] ]


tools : Model -> Html Msg
tools model =
    menu [ class "tools" ]
        [ toolItem (model.mode == DrawMode)
            [ button [ title "Draw mode", onClick (SetMode DrawMode) ]
                [ text "✍"
                ]
            ]
        , toolItem (model.mode == SelectMode)
            [ button [ title "Select mode", onClick (SetMode SelectMode) ]
                [ text "\x1F91A"
                ]
            ]
        , toolItem False
            [ input
                [ class "char-input"
                , title "Change character"
                , Html.Attributes.value model.char
                , onInput ChangeChar
                , maxlength 1
                , style [ ( "color", model.color ) ]
                ]
                []
            ]
        , toolItem False
            [ input
                [ class "color-input"
                , type_ "color"
                , title "Select color"
                , Html.Attributes.value model.color
                , onInput SetColor
                ]
                []
            ]
        , toolItem False
            [ button [ title "Erase all", onClick Clear ]
                [ text "🚫"
                ]
            ]
        ]


view : Model -> Html Msg
view model =
    main_ []
        [ h1 [] [ text "🎨 ASCII Canvas" ]
        , section [ class "container" ]
            [ table model
            , tools model
            ]
        ]


main : Program Never Model Msg
main =
    Html.beginnerProgram
        { model = initModel
        , view = view
        , update = update
        }
