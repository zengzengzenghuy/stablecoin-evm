const Web3 = require("web3");
const web3 = new Web3("https://rpc.gnosischain.com");
const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../../.env") });
const fs = require("fs");

const filePath = path.join(__dirname, "..", "test_output");

const USER_REQUEST_FOR_SIGNATURE =
  "0x520d2afde79cbd5db58755ac9480f81bc658e5c517fcae7365a3d832590b0183";

async function signAndGetSignature() {
  fs.readFile(
    filePath + "/GNO_relayTokens.json",
    { encoding: "utf-8" },
    (err, data) => {
      if (err) console.err(err);
      if (data) {
        let messageData;
        let messageId;
        const output = JSON.parse(data);

        output["foundry_test/USDC_test/gno.t.sol:gnoTest"]["test_results"][
          "test_relayUSDCEFromGC()"
        ]["logs"].forEach((log) => {
          if (log.topics[0] == USER_REQUEST_FOR_SIGNATURE) {
            console.log(
              "User Request for Signature Found with messageId ",
              log.topics[1]
            );
            if (log.data.substring(0, 6) != "0x0005")
              log.data = "0x" + log.data.substring(130);
            messageData = log.data;
            messageId = log.topics[1];
          }
        });
        const privateKey = process.env.VALIDATOR_PRIVATE_KEY;
        console.log("private key ", privateKey);

        const signed = web3.eth.accounts.sign(messageData, privateKey);
        const signature = signed.signature;
        console.log("Signature ", signature);
        // Collect signature.signature for next step
        const packedSignatures = packSignatures([signature]);
        const userRequestForSignatureData = {
          messageId,
          message: messageData,
          packedSignatures,
        };
        fs.writeFile(
          filePath + "/ETH_input.json",
          JSON.stringify(userRequestForSignatureData),
          () => {}
        );
      }
    }
  );
}

function packSignatures(signatures) {
  const _signatures = signatures.map((e) => signatureToVrs(e));
  const length = Number(_signatures.length).toString(16);

  const msgLength = length.length === 1 ? `0${length}` : length;

  let v = "";
  let r = "";
  let s = "";
  _signatures.forEach((e) => {
    v = v.concat(e.v);
    r = r.concat(e.r);
    s = s.concat(e.s);
  });

  return `0x${msgLength}${v}${r}${s}`;
  // console.log("packed signature", `0x${msgLength}${v}${r}${s}`)
}

function signatureToVrs(_rawSignature) {
  const signature = strip0x(_rawSignature);
  const v = signature.substr(64 * 2);
  const r = signature.substr(0, 32 * 2);
  const s = signature.substr(32 * 2, 32 * 2);
  return { v, r, s };
}

const strip0x = (_input) => _input.toString().replace(/^0x/, "");

signAndGetSignature();
