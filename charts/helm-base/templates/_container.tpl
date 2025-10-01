{{- define "helm-base.containerBase" -}}
{{- $name := include "helm-base.fullname" $ -}}

{{- $tag := "" }}
{{- if not $.image }}
{{- $tag = printf ":%s" (coalesce $.Values.image.tag $.Values.global.image.tag) }}
{{- end }}


- name: {{ tpl $.name $ }}
  image: "{{ tpl (tpl (coalesce $.image $.Values.image.repository $.Values.global.image.repository) $) $ }}{{ $tag }}"
  imagePullPolicy: {{ coalesce $.imagePullPolicy $.Values.global.imagePullPolicy "Always" }}
{{- if $.command }}  
  command: 
{{- $new := list }}
{{- range $_, $v := $.command }}
{{- with $v }}
{{- $new = append $new (tpl (tpl . $) $) }}
{{- end }}
{{- end }}
{{ toYaml $new | indent 2 }}
{{- end }}
{{- if $.args }}  
  args: 
{{- range $_, $v := $.args }}
{{- with $v }}
  - "{{ tpl . $ -}}"
{{- end }}
{{- end }}
{{- end }}

{{- if $.tty }}
  tty: true
{{- end }}

{{- if $.stdin }}
  stdin: true 
{{- end }}


{{- if $.workingDir }}
  workingDir: {{ tpl $.workingDir $ }}
{{- end }}
{{- if $.resources }}
  resources:
{{ tpl (toYaml $.resources) $ | indent 4 }}
{{- end -}} {{/* End resources */}}

{{- include "helm-base.volumeMounts" $ | indent 2 }}

{{- if $.privileged }}
  securityContext:
    privileged: true
{{- else if $.securityContext }}
  securityContext:
{{ toYaml $.securityContext | nindent 4 }}
{{- else }}
{{ include "helm-base.containerSecurityContext" $ | indent 2 }}
{{- end -}} {{/* End privileged */}}

{{- if or $.env $.Values.env $.Values.global.env $.envFrom $.Values.envFrom }}
{{- $envFromList := list }}
{{- if $.Values.envFrom }}
{{- $envFromList = concat $envFromList $.Values.envFrom }}
{{- end }}
{{- if $.envFrom }}
{{- $envFromList = concat $envFromList $.envFrom }}
{{- end }}
{{- if $envFromList }}
  envFrom:
{{- range $_, $e := $envFromList }}
  {{- if $e.configMapRef }}
  - configMapRef:
      name: {{if $e.configMapRef.fullname }}{{ $e.configMapRef.fullname }}{{else}}{{ $name }}-{{ $e.configMapRef.name }}{{end}}
  {{- else if $e.secretRef }}
  - secretRef:
      name: {{if $e.secretRef.fullname }}{{ $e.secretRef.fullname }}{{else}}{{ $name }}-{{ $e.secretRef.name }}{{end}}
  {{- end }}
{{- end }}
{{- end }}
{{- $envVars := deepCopy ($.Values.env | default dict) | mergeOverwrite (deepCopy ($.Values.global.env | default dict)) }}
  env:
{{- if $envVars }}
{{- range $dk, $dv := $envVars }}
  - name: {{ $dk }}
    value: "{{ with $dv }}{{ tpl (. | toString) $ }}{{end}}"
{{- end }}
{{- end }}
{{- if $.env }}
{{- range $k, $v := $.env }}
  - name: {{ $k }}
    value: "{{ with $v }}{{ tpl (. | toString) $ }}{{end}}"
{{- end }}
{{- end }}
{{- if or $.envRaw $.Values.envRaw $.Values.global.envRaw -}}
{{- $rawEnv := concat ($.envRaw | default list) ($.Values.envRaw | default list) ($.Values.global.envRaw | default list) }}
{{ toYaml $rawEnv | indent 2}}
{{- end }}
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_IP
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: status.podIP
{{- end }} {{/* End env */}}

{{- if $.waitFor -}}
{{- if $.waitFor.port }}
  livenessProbe:
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    tcpSocket:
      port: {{ $.waitFor.port }}
    timeoutSeconds: 1
  readinessProbe:
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    tcpSocket:
      port: {{ $.waitFor.port }}
    timeoutSeconds: 1
{{- else }}
{{- if $.waitFor.command }}
  livenessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    timeoutSeconds: {{ default 5 $.waitFor.timeoutSeconds }}
  readinessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    timeoutSeconds: {{ default 5 $.waitFor.timeoutSeconds }}
{{- end }} {{/* End .command */}}
{{- end }} {{/* End .waitFor.port */}}
{{- end }} {{/* End .waitFor */}}

{{- if $.readinessProbe }}
  readinessProbe:
{{ toYaml $.readinessProbe | indent 4 }}
{{- end }}

{{- if $.livenessProbe }}
  livenessProbe:
{{ toYaml $.livenessProbe | indent 4 }}
{{- end }}

{{- if $.startupProbe }}
  startupProbe:
{{ toYaml $.startupProbe | indent 4 }}
{{- end }}

{{- if $.ports }}
  ports:
{{- range $k, $v := $.ports }}
{{- if eq (kindOf $v) "map" }}
  - name: {{ $v.name }}
    containerPort: {{ $v.port }}
    protocol: {{ default "TCP" $v.protocol }}
{{- else }}
  - name: {{ printf "p-%s" ($k | toString) }}
    containerPort: {{ $v }}
    protocol: "TCP"
{{- end }}
{{- end }}
{{- end }}

{{- if $.lifecycle }}
  lifecycle:
{{ toYaml $.lifecycle | indent 4 }}
{{- end }}

{{- end }}