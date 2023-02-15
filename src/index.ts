import * as core from "@actions/core";

export async function printMsg(
    msg: string
  ){
    core.info(`info: ${msg}`);
}