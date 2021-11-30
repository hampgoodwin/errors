# errors

A simple helper package for errors in go.

[![Go Report Card](https://goreportcard.com/badge/github.com/hampgoodwin/errors)](https://goreportcard.com/report/github.com/hampgoodwin/errors) [![Coverage Status](https://coveralls.io/repos/github/hampgoodwin/errors/badge.svg?branch=main)](https://coveralls.io/github/hampgoodwin/errors?branch=main) [![golangci-lint](https://github.com/hampgoodwin/errors/actions/workflows/golint-ci.yml/badge.svg)](https://github.com/hampgoodwin/errors/actions/workflows/golint-ci.yml)

---

While the project is in v0.0.0 the api is not guaranteed.

## examples

### Wrap

Logging is where the simple wrap information is useful. Wrap information should never be used in interface values. If you want a specific message to surface to the interface, see the [WithMessage](#withmessage) example.

```go
type ErrorResponse struct {
    error string
    message string
}
func jsonResponseError(w http.ResponseWriter, err error) {
    logger.Error().LogError(err, "response")
    switch true {
        case erros.Is(err,errors.NotFound):
            w.WriteHeader(http.StatusOK)
            w.Write(json.Unmarshall(err))
        default:
            w.WriteHeader(http.StatusInternalServerError)
            w.Write(ErrorResponse{err.Error(), ""})
    }
}
func (c *controller) Get(w http.ResponseWriter, r *http.Request) {
    id := getURLParam(r, "id")
    it, err := s.GetIt(id)
    if err != nil {
        jsonResponseError(w, err)
    }
    jsonResponse(w, it)
} 
func(s *service) GetIt(id string) (It, error) {
    it, err := r.GetIt(id)
    if err != nil {
        return It{}, errors.Wrap(err, "service getting it")
    }
}
func (r *repo) GetIt(id string) (It, error) {
    qry := "SELECT * FROM it WHERE id = $1"
    var it It
    if err := db.QueryRow(qry,id).scan(&it); err != nil {
        if errors.Is(sql.ErrNoRows, err) {
        return It{}, errors.Wrap(err, "repo getting it")
    }
}

```

### WithMessage

WithMessage should be used when we have errors but we want to surface the error with a specific message without using a custom error. The highest in the chain WithMessage is used by default in this example.

In this example, we set a message that a record for the given id is not found. We really should, in this example, use [WithError](#witherror)(err, errors.NotFound) to indicate that the record is not found, but the example is contrived to show how we can use the Message Value as an interface value.

```go
type ErrorResponse struct {
    err string
    message string
}
func jsonResponseError(w http.ResponseWriter, err error) {
    var msg string
    var message errors.Message
    if errors.As(err, &message) {
        msg = message.Value
    }
    logger.Error().With("msg", msg).LogError(err)
    switch true {
        case erros.Is(err,errors.NotFound):
            w.WriteHeader(http.StatusNotFound)
            w.Write(ErrorResponse(errors.NotFound.Error(), msg))
        default:
            w.WriteHeader(http.StatusInternalServerError)
            w.Write(ErrorResponse{"unhandled internal error", msg})
    }
}
func (c *controller) Get(w http.ResponseWriter, r *http.Request) {
    id := getURLParam(r, "id")
    it, err := s.GetIt(id)
    if err != nil {
        jsonResponseError(w, err)
    }
    jsonResponse(w, it)
} 
func(s *service) GetIt(id string) (It, error) {
    it, err := r.GetIt(id)
    if err != nil {
        return It{}, errors.Wrap(err, "service getting it")
    }
}
func (r *repo) GetIt(id string) (It, error) {
    qry := "SELECT * FROM it WHERE id = $1"
    var it It
    if err := db.QueryRow(qry,id).scan(&it); err != nil {
        if errors.Is(sql.ErrNoRows, err) {
        return It{}, errors.WithMessage(err, fmt.Sprintf("no record for %q exists", id))
    }
}
```

### WithError

WithError allows us to combine an error _with_ another error.

**Simple**:

In this simple example, we us a sentinel error defined in the errors package to indicate that the error is not found. If you need more sentinel errors, feel free to define your own internal errors package and use those.

```go
type ErrorResponse struct {
    err string
    message string
}
func jsonResponseError(w http.ResponseWriter, err error) {
    var msg string
    var message errors.Message
    if errors.As(err, &message) {
        msg = message.Value
    }
    logger.Error().With("msg", msg).LogError(err)
    switch true {
        case erros.Is(err,errors.NotFound):
            w.WriteHeader(http.StatusNotFound)
            w.Write(ErrorResponse(errors.NotFound.Error(), msg))
        default:
    }
}
func (c *controller) Get(w http.ResponseWriter, r *http.Request) {
    id := getURLParam(r, "id")
    it, err := s.GetIt(id)
    if err != nil {
        jsonResponseError(w, err)
    }
    jsonResponse(w, it)
} 
func(s *service) GetIt(id string) (It, error) {
    it, err := r.GetIt(id)
    if err != nil {
        return It{}, errors.Wrap(err, "service getting it")
    }
}
func (r *repo) GetIt(id string) (It, error) {
    qry := "SELECT * FROM it WHERE id = $1"
    var it It
    if err := db.QueryRow(qry,id).scan(&it); err != nil {
        if errors.Is(sql.ErrNoRows, err) {
        return It{}, errors.With(err, errors.NotFound)
    }
}
```

**Custom Error Example**

We often may need more than simple wrapped errors, error messages, or sentinel errors. In these scenarios we can rely on custom errors and combine them alongside with other errors like in the example below. With these custom errors, we can have more options in our handling of the error.

```go
type ErrorResponse struct {
    err string
    message string
}
func jsonResponseError(w http.ResponseWriter, err error) {
    var msg string
    var message errors.Message
    if errors.As(err, &message) {
        msg = message.Value
    }
    logger.Error().With("msg", msg).LogError(err)
    var clerr CustomListError
    switch true {
        case erros.As(err, &clerr):
        w.WriteHeader(http.StatusInternalServerError)
            if clerr.Count > 1 {
                w.Write(ErrorResponse(clerr.Error(), msg))
            }
            if clerr.Count == 0 {
                w.Write(ErrorResponse(clerr.Error(), msg))
            }
            fallthrough
        default:
            w.WriteHeader(http.StatusInternalServerError)
            w.Write(ErrorResponse{"not handled", msg})
    }
}
func (c *controller) List(w http.ResponseWriter, r *http.Request) {
    id := getURLParam(r, "id")
    it, err := s.GetEm(id)
    if err != nil {
        jsonResponseError(w, err)
    }
    jsonResponse(w, it)
} 
func(s *service) List() ([]It, error) {
    it, err := r.List()
    if err != nil {
        return nil, errors.Wrap(err, "service getting it")
    }
}
type CustomListError struct {
    Count string
    Query string
}
func (cle CustomListError) Error() string {
    return fmt.Sprintf("expecting 1 records for query %q but found %q", cle.Count, cle.Query)
}
func (r *repo) List() ([]It, error) {
    qry := "SELECT * FROM it"
    rows, err := db.Query(qry)

    var em []It
    for rows.Next() {
        var it It
        err := rows.Scan(&it)
    }

    if len != 1 {
        return nil, CustomListError{
            Count: len(em),
            Query: qry,
        }
    }
    ...
}
```