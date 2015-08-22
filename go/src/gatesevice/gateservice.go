package main

import (
    "log"
    "os"
    "os/signal"
    "time"
    "fmt"
    "net/http"
    "strconv"

    "github.com/oleksandr/bonjour"
    "github.com/stianeikeland/go-rpio"
)

const kPort = 9999

func asyncPushButton(requests chan int, value int) {
	requests <- value
}

func buttonHandler(requests chan int) func (http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Printf("button handler %v", r)
                r.ParseForm()
                button, err := strconv.Atoi(r.Form.Get("k"))
                log.Printf("form %v button %v", r.Form, button)
                if err == nil {
	                go asyncPushButton(requests, button)
		}
	}
}

func processRequests(requests chan int) {
        pinMap := [...]int{0, 11, 9, 10, 22}
 	for gate := range requests {
		log.Printf("processing request %v", gate);
                if gate < 1 || gate > 4 {
			continue
		}
		err := rpio.Open()
		if err != nil {
			log.Println("Cant open GPIO")
			continue
		}
		pin := rpio.Pin(pinMap[gate])
		pin.Output()
		pin.High()
		time.Sleep(time.Second)
		pin.Low()
		rpio.Close()
		time.Sleep(time.Second)
	}
}

func main() {

    // Run registration (blocking call)
    s, err := bonjour.Register("GateOpen Service", "_gateservice._tcp", "", kPort, []string{"txtv=1", "app=test"}, nil)
    if err != nil {
        log.Fatalln(err.Error())
    }
    fmt.Println("Service registered")

    requests := make(chan int)
    go processRequests(requests)

    http.HandleFunc("/button", buttonHandler(requests))
    log.Fatal(http.ListenAndServe(":"+strconv.Itoa(kPort) , nil))

    fmt.Println("Serving")
    // Ctrl+C handling
    handler := make(chan os.Signal, 1)
    signal.Notify(handler, os.Interrupt)
    for sig := range handler {
        if sig == os.Interrupt {
            fmt.Println("Ctrl+C .. quiting")
            s.Shutdown()
            time.Sleep(1e9)
            break
        }
    }
}

