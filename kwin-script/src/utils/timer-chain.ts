import { exceptionHandler } from "../exception-handling/exception-handler";

/**
 * Interface representing a single timer chain item.
 */
interface TimerChainItem {
  funtionToCall: () => void;
  funtionLatency: number;
}

/**
 * Class to handle a timer chain.
 *
 * Allows chaining of timed functions to be executed sequentially.
 */
class TimerChain {
  /** The links, in the order they will run. */
  private timerChain: TimerChainItem[];

  /** How far along the chain we are. */
  private timerChainItemIndex: number;

  /** The timer of the link currently waiting. */
  private timerChainItemTimer: QTimer | null;

  /** Create an empty chain. Add links with "addTimerChainLink". */
  constructor() {
    this.timerChain = [];
    this.timerChainItemIndex = 0;
    this.timerChainItemTimer = null;
  }

  /**
   * Executes a function in the timer chain and proceeds to the next one.
   *
   * @param funtionToCall - The function to be called.
   */
  private runTimerChainItem(funtionToCall: () => void): void {
    exceptionHandler(() => {
      funtionToCall();
      if (this.timerChainItemTimer) {
        this.timerChainItemTimer.stop();
      }
      this.timerChainItemIndex++;
      if (this.timerChain.length > this.timerChainItemIndex) {
        this.runTimerChain();
      }
    });
  }

  /**
   * Executes a chain of timer-based functions sequentially.
   *
   * This method initializes a QTimer for the current item in the timer chain
   * and sets it to call the next function after the defined latency.
   */
  public runTimerChain(): void {
    if (this.timerChain.length < 1) {
      return;
    }
    this.timerChainItemTimer = new QTimer();
    const timerChainItem = this.timerChain[this.timerChainItemIndex];
    this.timerChainItemTimer.timeout.connect(() =>
      this.runTimerChainItem(timerChainItem.funtionToCall)
    );
    this.timerChainItemTimer.start(timerChainItem.funtionLatency);
  }

  /**
   * Adds a new link to the timer chain.
   *
   * @param funtionToCall - The function to be called when the timer expires.
   * @param funtionLatency - The latency in milliseconds before the function is called.
   */
  public addTimerChainLink(
    funtionToCall: () => void,
    funtionLatency: number
  ): void {
    this.timerChain.push({
      funtionToCall: funtionToCall,
      funtionLatency: funtionLatency,
    });
  }
}

export { TimerChain };

