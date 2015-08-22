package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"time"

	"github.com/oleksandr/bonjour"
	"github.com/stianeikeland/go-rpio"
)

const kPort = 9999
var kPinMap = [...]int{0, 11, 9, 10, 22}

func asyncPushButton(requests chan int, value int) {
	requests <- value
}

func buttonHandler(requests chan int) func(http.ResponseWriter, *http.Request) {
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
	for gate := range requests {
		log.Printf("processing request %v", gate)
		if gate < 1 || gate >= len(kPinMap) {
                        log.Printf("Invalid gate number %v", gate)
			continue
		}
		err := rpio.Open()
		if err != nil {
			log.Println("Cant open GPIO")
			continue
		}
		pin := rpio.Pin(kPinMap[gate])
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
	log.Fatal(http.ListenAndServe(":"+strconv.Itoa(kPort), nil))

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
