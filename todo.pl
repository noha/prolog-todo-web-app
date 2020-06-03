:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_head)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_session)).
:- use_module(library(http/http_parameters)).

% Set up server for port 7777
todo_server :- todo_server(7778).

todo_server(Port) :-
    format('Starting todo_server on ~w', [Port]),
    http_server(http_dispatch, [port(Port)]).


:- multifile http:location/3.
:- dynamic   http:location/3.

/*
 * Set up serving static web resources for URI /static
 *
 * Files are mapped directly to contained directory web/
 */
:- http_handler(static(.), serve_static_files, [prefix]).

http:location(static, root('static'), []).
user:file_search_path(web_root, 'web/').


serve_static_files(Request) :-
    http_reply_from_files(web_root('.'), [], Request).
serve_static_files(Request) :-
    http_404([], Request).

/*
 * Start page
 */
:- http_handler(/, start_page, [priority(100)]).

:- html_resource(bootstrap, [ virtual(true), requires(static('css/bootstrap.min.css')) ]).

/*
 * Start page that sets up CSS resources and calls default component todo
 */
start_page(_Request) :-
    reply_html_page([
        title('todo app'),
        \html_requires(bootstrap) ],
        [ \page_template(todo_component) ]).

/*
 *  Main todo component. List all created todos and a form
 */
todo_component -->
    { session_todos(Todos) },
    html([
        h1('my todos'),
        ul(class='list-group',[ \todo_list(Todos) ]),
         \new_todo_entry ]).

todo_list([]) -->
    html([]).

todo_list([Todo|Rest]) -->
    html(li(class='list-group-item',[
         \todo_remove_form(Todo)])),
    todo_list(Rest).

todo_remove_form(todo(Title-ID)) -->
    html(
       form([method(delete), action(location_by_id(remove_todo)+ID)], [
          Title,
          button([type(submit), class='btn btn-outline-danger btn-sm float-right'], 'X') ])).

new_todo_entry -->
    html(div(style='padding-top: 2em',[
       b('Add new todo'),
       form([method(post), action(todos)], [
          div(class='form-group row', [
             div(class='col col-11', [
                input([type(text), class='form-control', name('todo_title')], []) ]),
             div(class='col col-1', [
                 button([type(submit), class='btn btn-outline-primary float-right'], 'add') ])])])])
    ).


:- http_handler(root(todos), create_todo, []).


create_todo(Request) :-
    member(method(post), Request),
    http_parameters(Request, [todo_title(Todo, [string])]),
    random(1,10000,ID),
    atom_number(IDA, ID),
    session_todos(Todos),
    append(Todos, [todo(Todo-IDA)], NewTodos),
    update_session_todos(NewTodos),
    http_redirect(see_other, root(.), Request).

:- http_handler(root(todos/ID), remove_todo(ID), [ id(remove_todo)]).

remove_todo(ID, Request) :-
    session_todos(TodoItems),
    select(todo(_-ID), TodoItems, RemainingTodos),
    update_session_todos(RemainingTodos),
    http_redirect(see_other, root(.), Request).

/*
 * Creates a page template that is used to wrap components in a
 * common layout structure
 */
page_template(Component) -->
    html([
        div(class=container, [
            div(class=row, [
                div(class='col-12',
                \Component )
            ]) ]) ]).

/*
 * Session helpers to store and manage todos for the lifetime
 * of a session
 */
session_todos(Todos) :-
    http_session_data(to_dos(Todos)), !.

session_todos([]) :-
    http_session_assert(to_dos([])).

update_session_todos(TodoItems) :-
    http_session_retractall(to_dos(_)),
    http_session_assert(to_dos(TodoItems)).
