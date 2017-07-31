// @flow
import {type Channel, eventChannel, END} from 'redux-saga'
import {call} from 'redux-saga/effects'
import generateUniqueId from 'uuid/v4'
import wn from 'when'
import {typeof BrowserWindow, ipcMain} from 'electron'

type Request = {
  type: string,
  id: string,
  payload: mixed,
}

type Response = {
  id: string,
  payload: mixed,
}

type RequestFromWindow = {
  type: string,
  payload: mixed,
  respond: (payload: mixed) => void,
}

export function* autoRetryOnTimeout(callee: Function, args: Array<mixed>, numberOfRetries: number = 10): Generator<> {
  let retries = -1
  while(true) {
    retries++
    try {
      return yield call(callee, ...args)
    } catch (e) {
      if (e !== 'timeout') {
        throw e
      } else if (retries === numberOfRetries) {
        throw e
      }
    }
  }
}

/**
 * @note If you set the timeout arg to a big number (say 10000ms), then we'll have a memory leak caused
 * by having set up too many listeners on ipcMain
 */
export function sendRequestToWindow(window: BrowserWindow, type: string, payload: mixed, timeout: number = 4000): Promise<mixed> {
  const request = {
    id: generateUniqueId(),
    type, payload,
  }

  // @todo implement a timeout
  const payloadDeferred = wn.defer()
  let responded = false

  const listener = (event, response: Response) => {
    if (response.id === request.id) {
      ipcMain.removeListener('response', listener)
      responded = true
      payloadDeferred.resolve(response.payload)
    }
  }

  ipcMain.on('response', listener)
  window.webContents.send('request', request)

  // if the response doesn't come within the specified timeout period, then we'll remove
  // listneer from ipcMain, and reject with 'timeout' being the reason
  const timeoutAndGCPromise = wn().delay(timeout).then(() => {
    if (!responded) {
      ipcMain.removeListener('response', listener)
      return wn.reject('timeout')
    }
  })

  return wn.race([payloadDeferred.promise, timeoutAndGCPromise])

}

export const getChannelOfRequestsFromWindow = (window: BrowserWindow): Channel => {
  return eventChannel((emitToChannel) => {
    const listener = (event, request: Request) => {
      if (event.sender !== window.webContents) {
        console.log('got st but not from this window')
        return
      }

      let alreadyResponded = false
      const respond = (payload: mixed) => {
        if (alreadyResponded)
          throw new Error(`Request '${request.id}' to '${request.type}' is already responded to`)

        alreadyResponded = true
        event.sender.send('response', {id: request.id, payload})
      }

      emitToChannel(({
        type: request.type,
        payload: request.payload,
        respond,
      }: RequestFromWindow))
    }

    ipcMain.on('request', listener)

    window.on('closed', () => {
      emitToChannel(END)
    })

    const unsubscribe = () => {
      ipcMain.removeListener('request', listener)
    }

    return unsubscribe
  })
}