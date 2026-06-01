# flask-make-demo

Börja med att klona repot, eller forka det på github.com:

```sh
git clone https://github.com/jonasbjork/flask-make-demo.git
```

## Projektet

Projektet är en minimal Flask-app med två endpoints, några tester och en `Dockerfile`. Poängen är inte appen utan `Makefile` som styr arbetsflödet.

```txt
flask-make-demo/
├── app/
│   ├── __init__.py
│   └── main.py
├── tests/
│   └── test_main.py
├── requirements.txt
├── Dockerfile
└── Makefile
```

## Flask-appen

Flask-appen, `app/main.py`, är minimal. Den har två endpoints. Index returnerar ett meddelande om status och health returnerar om appen lever. Health är en typisk endpoint för att kontrollera hälsan i applikationer, ni kommer stöta på den i nästan alla webbapplikationer i produktion. Kubernetes använder `/health` för att avgöra om en container mår bra.

Notera `host='0.0.0.0'`, det behövs för att appen ska kunna nås utifrån containern. Om vi använder `localhost` eller `127.0.0.1` lyssnar appen bara innuti containern och kan inte nås utifrån med till exempel `curl` eller vår webbläsare.

## Testerna

Testerna, `tests/test_main.py`, använder Flasks inbyggda testklient. Den skickar HTTP-anrop mot appen i minnet utan att starta en server. Det gör att testerna blir snabba (ett par millisekunder) och determistiska, det vill säga att de ger samma resultat varje gång.

Vi har två tester: ett för index-endpointen och ett för health. Vi kontrollerar statuskod och innehåll. Enkelt, men tillräckligt för att demonstrera att `make` stoppar kedjan om testerna fallerar.

## Beroenden

`requirements.txt` innehåller flask och pytest. Notera att vi använder `==` för versionerna. Det kallas för att vi pinnar versionerna. Om vi istället skriver `>=` kan vi få den senaste versionen just nu, men när vi kör samma kommando nästa vecka kanske vi får en helt annan version. Om den nya versionen har en bugg, eller ändrat på sitt API fungerar inte våra tester helt plötsligt och vi förstår inte varför. Vi har ju inte ändrat något.

Pinnade versioner tar bort den osäkerheten. `flask==3.1.1` ger oss Flask 3.1.1 idag, imorgon och om ett år.

## Dockerfile

Dockerfilen känner ni förhoppningsvis igen. Vi använder Python 3.12-slim som base image. Slim-varianten är mindre och saknar kompileringsverktyg som vi inte behöver. Det jag vill att ni lägger märke till är ordningen i `Dockerfile`.

Vi kopierar `requirements.txt` först och installerar dependencies. Sedan kopierar vi appkoden. Varför? Docker-lagercache. Docker bygger i lager och varje instruktion i `Dockerfile` är ett lager. Om ett lager inte ändrats återanvänder Docker det lagret cachat. Genom att lägga `requirements.txt` innan appkoden ser Docker att *requirements har inte ändrats sedan förra bygget så jag återanvänder lagret med installerade paket*. Det snabbar upp bygget av containern och vi slipper sitta och vänta på att `pip` ska ladda ner Flask varje gång vi ändrar en rad kod.

`--no-cache-dir` säger åt `pip` att inte spara nedladdade filer i imagen. Det minskar storleken och varje megabyte spelar roll i container-images.

## Makefile

Nu bygger vi Makefilen.

### Variabler och phony

```Makefile
APP_NAME    := flask-make-demo
PYTHON      := python3
PIP         := pip
DOCKER      := docker
IMAGE_TAG   := latest
GIT_SHA     := $(shell git rev-parse --short HEAD 2>/dev/null \
               || echo "no-git")

.PHONY: help install test lint build clean docker-build docker-run
```

- Allt är konfiguerbart: byt `docker` till `podman` på en rad om du vill använda `podman` istället
- `GIT_SHA` med fallback om git saknas
- Alla targets är deklarerade som phony

## Target: `help`

```Makefile
help:
	@echo ""
	@echo "Tillgängliga targets:"
	@echo ""
	@echo "  make install       Installera dependencies"
	@echo "  make test          Kör pytest"
	@echo "  make lint          Kodkontroll"
	@echo "  make build         Verifiera allt"
	@echo "  make clean         Rensa tempfiler"
	@echo "  make docker-build  Bygg Docker-image"
	@echo "  make docker-run    Kör i container"
	@echo ""
```

Vår första target är `help` som körs om någon bara skriver `make`. Alla echo-rader har `@`-prefix så att vi inte ser `echo` utmatat. Strukturen är enkel: en lista med alla targets och vad de gör.

## Targets: `install`, `test` och `lint`

```Makefile
install:
	$(PIP) install -r requirements.txt

test: install
	$(PYTHON) -m pytest tests/ -v

lint:
	$(PYTHON) -m py_compile app/main.py
```

Install kör `pip install`. Test kör `pytest` med verbose-flaggan. Lint gör en enkel syntaxkontroll med `py_compile`. 

Det viktiga här är beroendet: test har install som dependency. Det innebär att om vi kör `make test` och inte har installerat dependencies ännu kommer `make` göra det åt oss. Och om `pip install` misslyckas, till exempel för att `requirements.txt` har ett paket som inte finns, stannar `make` och `pytest` körs aldrig. pytest körs med `-v` för verbose. Det ger oss en mer detaljerad utmatning: varje test med namn och resultat. Under utveckling vill vi se det.

`py_compile` är det enklast möjliga lint-steget. Det kontrollerar att filen har giltig Python-syntax. I en riktig miljö skulle vi använda `ruff`, `flake8` eller `pylint` istället, men `py_compile` duger för vår övning.

## Targets: `build` och `clean`

```Makefile
build: test lint
	@echo ""
	@echo "Build klar - alla tester och kontroller passerade."

clean:
	rm -rf __pycache__ app/__pycache__ tests/__pycache__
	rm -rf .pytest_cache
	rm -rf *.egg-info dist build
	@echo "Rensat."
```

Build är en abstrakt target. Den producerar ingen fil och den bygger ingen Docker-image. Allt den gör är att köra test och lint och bekräfta att allt passerar. Tänk på det som en snabb validering: *är min kod okej just nu?*. Det är ett användbart kommando under utveckling. Vi kör kommandot `make build` och om vi får tillbaka *Build klar* vet vi att koden kompilerar och att testerna passerar. Utan att behöva bygga en docker-image varje gång.

Clean rensar upp pythons `__pycache__`-kataloger, pytests cache och andra temporära filer och kataloger. Konventionen är att `make clean` ska ta bort allt som `make` har skapat, eller i alla fall allt temporärt. Repot ska efter clean vara nära sitt ursprungsläge. Notera att vi inte tar bort installerad virtualenv eller docker-images. Det vore att gå för långt, eftersom att det tar tid att installera om. Clean ska vara snabb och rensa bort skräp, inte tvinga oss från att börja om från noll.

## Target: `docker-build`

```Makefile
docker-build: test
	$(DOCKER) build -t $(APP_NAME):$(IMAGE_TAG) .
	$(DOCKER) build -t $(APP_NAME):$(GIT_SHA) .
	@echo ""
	@echo "Image byggd:"
	@echo "  $(APP_NAME):$(IMAGE_TAG)"
	@echo "  $(APP_NAME):$(GIT_SHA)"
```

- Beror på `test` vilket gör att vi inte skapar någon image om testerna fallerar
- Två taggar: `latest` och commit-sha
- Override utifrån: `make docker-build IMAGE_TAG=v1.0.0`

Det här är den target som binder ihop make-världen med docker-världen. `docker-build` beror på `test` vilket betyder att vi aldrig ska bygga en image om testerna inte gått genom. Det här är den typ av skyddsnät som vi vill ha automatiskt, inte som något vi måste komma ihåg manuellt.

Vi bygger imagen med två taggar. Först `IMAGE_TAG` som är `latest` som standard, men kan ersättas (override). Sedan har vi `GIT_SHA` som är commit-hashen. `latest` är bekvämt men rörlig. Commit-sha är oföränderlig och spårbar. Tekniskt sett kör vi docker build två gånger, men det andra bygget går direkt tack vara Dockers cache. Alla lager finns ju redan.

De sista raderna skriver ut vilka taggar som skapades. Trevligt att se vad som skapats.

Låt oss testa detta nu. Kör `make docker-build`. Titta på vad som händer: install, test, docker build. Allt som det ska.

## Target: `docker-run`

```Makefile
docker-run:
	$(DOCKER) run --rm -p 3000:3000 $(APP_NAME):$(IMAGE_TAG)
```

`docker-run` startar containern lokalt. `--rm` tar bort containern automatiskt när den stoppas så vi slipper städa upp själva. `-p 3000:3000` mappar port 3000 i containern till port 3000 på vår egen dator.

Notera att `docker-run` *inte* är beroende av `docker-build`. Det är medvetet. Om vi redan har byggt imagen vill vi kunna starta den direkt utan att behöva bygga om. Om vi vill ha hela kedjan kör vi `make docker-build` först och sedan `make docker-run`.

```sh
$ make docker-run
```

Öppna sedan en ny terminal, eller din webbläsare och anslut till tjänsten:

```sh
$ curl http://localhost:3000/health
{"healthy": true}
```

## Hela kedjan `make docker-build`

```txt
make docker-build
│
├── install       pip install -r requirements.txt
│
├── test          pytest tests/ -v
│   └── (failar?) => STOPP - ingen image byggs
│
└── docker-build  docker build -t flask-make-demo:latest .
                  docker build -t flask-make-demo:a1b2c3d .
```

Ett enda kommando, `make docker-build`, och `make` tar hand om resten. Install, test, docker build. I rätt ordning, med felhantering inbyggd. Det är det här som gör `make` till ett byggsystem. Det är beroendekedjan och felhanteringen. Om ett test fallerar så stoppas allt. Om install failar når vi aldrig test.

Kör `make docker-build` och se att allt går genom. Sedan går du in i testfilen och ändra en assert till något som inte stämmer. Till exempel `assert data['status'] == 'fel'` istället för `ok`. Kör `make docker-build` igen. Nu kommer du se att testerna fallerar och att docker build aldrig körs.


## Samma `Makefile` i CI

```yaml
# .github/workflows/ci.yml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-python@v5
    with:
      python-version: '3.12'
  - run: make build
  - run: make docker-build IMAGE_TAG=${{ github.sha }}
````

Här är ett workflow som hör till GitHub Actions. Vad står det i det? `make build` och `make docker-build`. Samma kommandon som vi kör lokalt på vår egen dator. Det betyder att om pipelinen går sönder kan vi reproducera problemet på vår egen maskin. `make build`, aha lint fallerar. Fixa, pusha och pipelinen blir grön igen Inga gissningar. Ingen skillnad mellan lokalt och CI.

